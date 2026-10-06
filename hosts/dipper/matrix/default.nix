{ config, pkgs, ... }:
let
  domain = "matrix.xsfx.dev";
  hsPort = 6167; # tuwunel plain HTTP, behind Caddy
  clientPort = 61643; # Caddy listens here; tlsrouter SNI-forwards :443 -> here
  federPort = 8448; # federation: other homeservers hit matrix.xsfx.dev:8448
  waAppPort = 29318; # mautrix-whatsapp appservice HTTP listener
  sgAppPort = 29328; # mautrix-signal appservice HTTP listener
  # Bridge admin: only @marv. Anyone else on ${domain} (e.g. the wife later) is a
  # normal user. `*` = relay (external federated users only via relay, never as
  # their own account). bridgev2 levels are relay < user < admin.
  bridgePermissions = {
    "@marv:${domain}" = "admin";
    "${domain}" = "user";
    "*" = "relay";
  };
  # Self-hosted Element (web client). Bake in the homeserver via override so
  # browsers load the client from www.${domain} but talk to ${domain} directly.
  elementWeb = pkgs.element-web.override {
    conf = {
      default_server_config = {
        "m.homeserver" = {
          base_url = "https://${domain}";
          # Without this the login form shows the default server_name (matrix.org).
          server_name = domain;
        };
        "m.identity_server" = {
          base_url = "";
        }; # no identity/3PID server
        # Force the MatrixRTC/Element Call path. The widget is bundled with
        # element-web (widgets/element-call), so no separate host is needed. The
        # legacy 1:1 stack would want coturn + turn_uris on tuwunel, which we
        # deliberately don't run.
        "element_call".use_exclusively = true;
      };
    };
  };
in
{
  # MatrixRTC (LiveKit + lk-jwt + TURN/TLS) lives in its own module; the bridges
  # are option modules, kept separate so they can be reused by another host.
  imports = [
    ./turn.nix
    ./mautrix-telegram-go.nix
    ./mautrix-slack.nix
  ];

  # Federation + client API both need inbound TCP. The MatrixRTC ports are opened
  # in turn.nix, next to the services that need them.
  networking.firewall.allowedTCPPorts = [
    443
    8448
  ];

  # The mautrix E2EE bridges build against libolm (olm), which upstream has
  # stopped maintaining -> marked insecure in nixpkgs. Opt in explicitly.
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  # --- Homeserver: tuwunel (successor to conduwuit) ---
  services = {
    matrix-tuwunel = {
      enable = true;
      settings.global = {
        server_name = domain; # not `inherit domain` — that would set `.domain`, not `.server_name`
        port = [ hsPort ]; # tuwunel: port is a list
        allow_registration = false; # <-- registration CLOSED again after creating @marv account
        allow_encryption = true;
        allow_federation = true;
        # Element X reads the RTC focus from
        # /_matrix/client/unstable/org.matrix.msc4143/rtc/transports, which tuwunel
        # builds from livekit_url. `client` is required alongside it.
        well_known = {
          client = "https://${domain}";
          livekit_url = "https://${domain}/livekit/jwt";
        };
        # Conduit-family design: persists room state, not the full event timeline,
        # so the DB stays bounded (no Synapse-style unbounded growth).
      };
    };

    # --- TLS termination + reverse proxy ---
    # tlsrouter owns :443 (SNI) and forwards matrix.xsfx.dev -> the Caddy listener
    # on clientPort; federation comes in directly on :8448. Both are the same site
    # so Caddy auto-provisions ONE Let's Encrypt cert for matrix.xsfx.dev.
    caddy = {
      enable = true;
      email = "marv@xsfx.dev";
      extraConfig = ''
        ${domain}:${toString clientPort}, ${domain}:${toString federPort} {
          # `handle` blocks are mutually exclusive and evaluated in written order,
          # so the specific paths come first and the homeserver catch-all last.

          # MatrixRTC. The bundled Element Call widget asks
          # `<livekit_service_url>/sfu/get`, and rtc_foci below advertises that URL
          # with the /livekit/jwt prefix -- so strip the prefix: lk-jwt serves
          # /sfu/get and /get_token at its root.
          # The ports come from the modules themselves (turn.nix), never a second
          # copy of the number, so the target cannot drift from the listener.
          handle_path /livekit/jwt/* {
            reverse_proxy 127.0.0.1:${toString config.services.lk-jwt-service.port}
          }
          # LiveKit signalling (the websocket itself is at /rtc) and its HTTP API.
          handle /rtc* {
            reverse_proxy 127.0.0.1:${toString config.services.livekit.settings.port}
          }
          handle /twirp* {
            reverse_proxy 127.0.0.1:${toString config.services.livekit.settings.port}
          }

          # Matrix discovery: tuwunel doesn't serve well-known, so Caddy does.
          # Needed so browsers (Element/app.element.io) can discover the homeserver,
          # and for rtc_foci -- Element Web reads the call focus from here, not from
          # tuwunel's transports endpoint.
          @wkclient path /.well-known/matrix/client
          @wkserver path /.well-known/matrix/server
          handle @wkclient {
            header {
              Access-Control-Allow-Origin "*"
              Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
              Access-Control-Allow-Headers "X-Requested-With, Content-Type, Authorization"
              Content-Type "application/json"
            }
            respond `{"m.homeserver":{"base_url":"https://${domain}"},"org.matrix.msc4143.rtc_foci":[{"type":"livekit","livekit_service_url":"https://${domain}/livekit/jwt"}]}`
          }
          handle @wkserver {
            respond `{"m.server":"${domain}:${toString federPort}"}`
          }

          # Everything else (/_matrix, /_synapse, appservice callbacks) is the
          # homeserver.
          handle {
            reverse_proxy 127.0.0.1:${toString hsPort}
          }
        }
        # Self-hosted Element web client. Served same-origin through the same
        # Caddy listener; SNI differs, so tlsrouter routes www.${domain} here.
        www.${domain}:${toString clientPort} {
          root * ${elementWeb}
          # The extra `{path}/index.html` matters: Caddy's try_files only probes
          # files, not directories, so `/usercontent/` (Element's sandboxed
          # download iframe target) would otherwise fall through to the SPA shell
          # and file downloads would silently do nothing.
          try_files {path} {path}/index.html /index.html
          encode gzip
          file_server
        }
      '';
    };

    # --- Edge: point the Matrix domain's SNI at our Caddy listener ---
    tlsrouter.routes.${domain}.backend = "127.0.0.1:${toString clientPort}";
    # Element web client on its own subdomain.
    tlsrouter.routes."www.${domain}".backend = "127.0.0.1:${toString clientPort}";

    # ---------------------------------------------------------------------------
    # Bridges: each a mautrix appservice. homeserver domain/address are set manually
    # because tuwunel isn't auto-detected by the mautrix modules (only synapse +
    # matrix-conduit are). Appservice REGISTRATION is done once per bridge via the
    # admin room: `!admin appservices register` + the generated
    # /var/lib/mautrix-<b>/*-registration.yaml (see docs: no restart, persisted).
    # ---------------------------------------------------------------------------

    # WhatsApp & Signal need no secrets (tokens auto-generate; pairing is via QR).

    # Telegram: Go bridgev2 (mautrix-telegram-go), in daily use. Needs API_ID/API_HASH in sops
    # (`mautrix-telegram-env`), read by the bridge as MAUTRIX_TELEGRAM_NETWORK__API_ID
    # / __API_HASH (double underscore = the `.` in config path network.api_id). bridgev2
    # only accepts relay/user/admin (NOT the Python "full").
    mautrix-telegram-go = {
      enable = true;
      package = pkgs.mautrix-telegram; # Go bridge, shadows nixpkgs' legacy Python one
      environmentFile = config.sops.secrets."mautrix-telegram-env".path;
      settings = {
        homeserver = {
          address = "http://127.0.0.1:${toString hsPort}";
          inherit domain;
        };
        bridge.permissions = bridgePermissions;
      };
    };

    mautrix-whatsapp = {
      enable = true;
      settings = {
        homeserver = {
          address = "http://127.0.0.1:${toString hsPort}";
          inherit domain;
        };
        # appservice.address = the URL tuwunel pushes events TO = THIS bridge's own
        # HTTP listener (port 29318), NOT the homeserver port.
        appservice.address = "http://127.0.0.1:${toString waAppPort}";
        bridge.permissions = bridgePermissions;
      };
    };

    mautrix-signal = {
      enable = true;
      settings = {
        homeserver = {
          address = "http://127.0.0.1:${toString hsPort}";
          inherit domain;
        };
        # appservice.address = the URL tuwunel pushes events TO = THIS bridge's own
        # HTTP listener (port 29328), NOT the homeserver port.
        appservice.address = "http://127.0.0.1:${toString sgAppPort}";
        bridge.permissions = bridgePermissions;
      };
    };

    # Slack: Go bridgev2 (mautrix-slack, already the Go rewrite in nixpkgs).
    # No secrets in sops — auth is per-session via `login token <xoxc-…> <xoxd-…>`
    # in the Slack bot DM (token + `d` cookie from the Slack web app; they expire,
    # so re-login when Slack rotates them).
    mautrix-slack = {
      enable = true;
      settings = {
        homeserver = {
          address = "http://127.0.0.1:${toString hsPort}";
          inherit domain;
        };
        bridge.permissions = bridgePermissions;
      };
    };
  };
}
