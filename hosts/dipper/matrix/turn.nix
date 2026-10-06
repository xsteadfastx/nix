# MatrixRTC: LiveKit (the SFU) + lk-jwt-service (Matrix -> LiveKit tokens), plus
# LiveKit's built-in TURN for clients whose network blocks direct media.
#
# A Matrix homeserver never carries media -- tuwunel stores events, not RTP -- so
# group calls need an external SFU, and the SFU speaks LiveKit JWTs rather than
# Matrix. Those two daemons are the minimum the protocol defines; the rest is
# plumbing around them. Both are stateless: there is nothing here to back up.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "matrix.xsfx.dev";
  # CNAME -> matrix.xsfx.dev, so it moves with it. Exists only to give TURN/TLS
  # its own SNI name: a :443 slot can route to exactly one backend, and that has
  # to be LiveKit.
  turnDomain = "turn.xsfx.dev";
  # Port for the certificate-only Caddy site below. Nothing ever connects to it,
  # and it is not in the firewall, so it is deliberately arbitrary: the certificate
  # does not depend on which port that site listens on, which is why this number
  # cannot drift into a bug.
  certSitePort = 61644;
  # Where Caddy keeps the certificates it issues (certmagic's on-disk layout).
  caddyCertDir = "${config.services.caddy.dataDir}/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${turnDomain}";
  certFile = "${caddyCertDir}/${turnDomain}.crt";
  keyFile = "${caddyCertDir}/${turnDomain}.key";

  cfg = config.services.livekit;
in
{
  services = {
    livekit = {
      enable = true;
      keyFile = config.sops.secrets."livekit-key".path;
      settings = {
        port = 7880; # HTTP/WS signalling; Caddy proxies /rtc and /twirp here
        rtc = {
          tcp_port = 7881; # ICE/TCP, for clients whose UDP is blocked
          port_range_start = 50100; # media over UDP
          port_range_end = 50200;
          # ponytail: this box's interface already carries the public IPv4 (tlsrouter
          # logs 195.201.150.255:443 as its local address), so the ICE host
          # candidates are routable as-is. Set use_external_ip = true only if media
          # fails to establish -- that makes LiveKit discover the IP via STUN
          # instead, which is what you want behind real NAT.
        };
        room.auto_create = false; # rooms come from lk-jwt (local users only)
        turn = {
          # LiveKit's own TURN, so no coturn. It only serves LiveKit's clients,
          # which is exactly what Element Call is; the legacy stack that wanted a
          # standalone coturn is gone from Element.
          enabled = true;
          udp_port = 3478;
          # LiveKit advertises turns:<domain>:443 no matter what this says, so
          # tlsrouter feeds it :443 (see below) and it listens here.
          tls_port = 5349;
          domain = turnDomain;
          cert_file = "/run/credentials/livekit.service/turn-cert";
          key_file = "/run/credentials/livekit.service/turn-key";
          relay_range_start = 50300; # must not overlap rtc.port_range_*
          relay_range_end = 60000;
        };
      };
    };

    lk-jwt-service = {
      enable = true;
      livekitUrl = "wss://${domain}"; # where clients reach the SFU, i.e. /rtc via Caddy
      keyFile = config.sops.secrets."livekit-key".path;
      port = 8081; # 8080 is the telegram bridge's appservice listener
    };

    # TURN/TLS: WebRTC clients dial ${turnDomain}:443 and tlsrouter hands the raw
    # TLS straight to LiveKit, which terminates it.
    tlsrouter.routes.${turnDomain}.backend = "127.0.0.1:${toString cfg.settings.turn.tls_port}";

    # --- The TURN/TLS certificate ---
    # Caddy is this host's only ACME client and already holds :80 (it binds it for
    # its own HTTP->HTTPS redirects), so a second ACME client cannot have that port
    # -- which is exactly how the standalone `security.acme` attempt failed, leaving
    # the module's self-signed fallback in place for LiveKit to serve.
    #
    # So Caddy issues this certificate too, and LiveKit gets the files below. Caddy
    # only issues for names in its config, hence the site. Nothing ever reaches it:
    # tlsrouter sends turn.xsfx.dev:443 to LiveKit, not here. TLS-ALPN-01 is
    # disabled because that challenge needs the :443 slot LiveKit occupies.
    caddy.extraConfig = lib.mkAfter ''
      ${turnDomain}:${toString certSitePort} {
        tls {
          issuer acme {
            disable_tlsalpn_challenge
          }
        }
        respond 404
      }
    '';
  };

  systemd = {
    services = {
      # The module doesn't expose this option, and its default ("*") would let any
      # federated user create rooms on our SFU and spend our bandwidth.
      lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = domain;

      # --- Gate LiveKit on the certificate existing ---
      # Caddy orders the certificate asynchronously, so `after caddy.service` is not
      # enough: LiveKit lost that race on the first deploy and died with exit status
      # 243/CREDENTIALS, which aborted the activation script with it. Wait on the file
      # instead. The wait is bounded, so a broken ACME setup fails the deploy with the
      # message below instead of hanging it.
      livekit-wait-turn-cert = {
        description = "Wait for Caddy to issue the TURN/TLS certificate";
        requires = [ "caddy.service" ];
        after = [ "caddy.service" ];
        before = [ "livekit.service" ];
        path = [ pkgs.coreutils ]; # sleep
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = 150; # > the 120s budget below
          ExecStart = pkgs.writeShellScript "wait-for-turn-cert" ''
            for ((i = 0; i < 60; i++)); do
              if [ -f ${certFile} ] && [ -f ${keyFile} ]; then
                exit 0
              fi
              sleep 2
            done
            echo "timed out after 120s waiting for Caddy to issue ${certFile}" >&2
            echo "is ${turnDomain} resolving and port 80 reachable? see docs/matrix.md" >&2
            exit 1
          '';
        };
      };

      # systemd reads the cert as root and drops it into the DynamicUser's
      # $CREDENTIALS_DIRECTORY, so LiveKit needs no group/ownership fiddling (Caddy's
      # key is 0600 caddy:caddy), and a missing cert fails loudly instead of quietly
      # serving TURN without TLS.
      #
      # ponytail: that is Caddy's on-disk layout, not an interface. If a Caddy upgrade
      # moves it, LiveKit stops starting -- the loud kind of wrong. LiveKit also reads
      # the files only at start, so after a renewal it keeps the old cert until
      # restarted; Caddy renews ~30 days before expiry, so there is no rush.
      livekit = {
        wants = [
          "caddy.service"
          "livekit-wait-turn-cert.service"
        ];
        serviceConfig.LoadCredential = [
          "turn-cert:${certFile}"
          "turn-key:${keyFile}"
        ];
      };
    };
  };

  # --- The ports all of this needs. Derived from the settings above, so a
  # listener and the firewall hole in front of it can never disagree. ---
  networking = {
    firewall = {
      allowedTCPPorts = [
        80 # Caddy's ACME HTTP-01, which is how the TURN certificate gets issued
        cfg.settings.rtc.tcp_port
      ];
      allowedUDPPorts = [ cfg.settings.turn.udp_port ];
      allowedUDPPortRanges = [
        {
          from = cfg.settings.rtc.port_range_start;
          to = cfg.settings.rtc.port_range_end;
        }
        {
          from = cfg.settings.turn.relay_range_start;
          to = cfg.settings.turn.relay_range_end;
        }
      ];
    };
  };
}
