{ config, ... }:
let
  domain = "matrix.xsfx.dev";
  hsPort = 6167; # tuwunel plain HTTP, behind Caddy
  clientPort = 61643; # Caddy listens here; tlsrouter SNI-forwards :443 -> here
  federPort = 8448; # federation: other homeservers hit matrix.xsfx.dev:8448
  waAppPort = 29318; # mautrix-whatsapp appservice HTTP listener
  sgAppPort = 29328; # mautrix-signal appservice HTTP listener
  tgAppPort = 8080; # mautrix-telegram appservice HTTP listener
in
{
  # Federation + client API both need inbound TCP.
  networking.firewall.allowedTCPPorts = [
    443
    8448
  ];

  # The mautrix E2EE bridges build against libolm (olm), which upstream has
  # stopped maintaining -> marked insecure in nixpkgs. Opt in explicitly.
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  # --- Homeserver: tuwunel (successor to conduwuit) ---
  services.matrix-tuwunel = {
    enable = true;
    settings.global = {
      server_name = domain; # not `inherit domain` — that would set `.domain`, not `.server_name`
      port = [ hsPort ]; # tuwunel: port is a list
      allow_registration = false; # <-- registration CLOSED again after creating @marv account
      allow_encryption = true;
      allow_federation = true;
      # Conduit-family design: persists room state, not the full event timeline,
      # so the DB stays bounded (no Synapse-style unbounded growth).
    };
  };

  # --- TLS termination + reverse proxy ---
  # tlsrouter owns :443 (SNI) and forwards matrix.xsfx.dev -> the Caddy listener
  # on clientPort; federation comes in directly on :8448. Both are the same site
  # so Caddy auto-provisions ONE Let's Encrypt cert for matrix.xsfx.dev.
  services.caddy = {
    enable = true;
    email = "marv@xsfx.dev";
    extraConfig = ''
      ${domain}:${toString clientPort}, ${domain}:${toString federPort} {
        # Matrix discovery: tuwunel doesn't serve well-known, so Caddy does.
        # Needed so browsers (Element/app.element.io) can discover the homeserver.
        @wkclient path /.well-known/matrix/client
        @wkserver path /.well-known/matrix/server
        respond @wkclient `{"m.homeserver":{"base_url":"https://${domain}"}}`
        respond @wkserver `{"m.server":"${domain}:${toString federPort}"}`
        header @wkclient {
          Access-Control-Allow-Origin "*"
          Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
          Access-Control-Allow-Headers "X-Requested-With, Content-Type, Authorization"
          Content-Type "application/json"
        }
        reverse_proxy 127.0.0.1:${toString hsPort}
      }
    '';
  };

  # --- Edge: point the Matrix domain's SNI at our Caddy listener ---
  services.tlsrouter.routes.${domain}.backend = "127.0.0.1:${toString clientPort}";

  # ---------------------------------------------------------------------------
  # Bridges: each a mautrix appservice. homeserver domain/address are set manually
  # because tuwunel isn't auto-detected by the mautrix modules (only synapse +
  # matrix-conduit are). Appservice REGISTRATION is done once per bridge via the
  # admin room: `!admin appservices register` + the generated
  # /var/lib/mautrix-<b>/*-registration.yaml (see docs: no restart, persisted).
  # ---------------------------------------------------------------------------

  # Telegram skipped for now: my.telegram.org returns generic "ERROR" for this
  # account (likely rate-limit/2FA), so the API_ID/API_HASH aren't available.
  # WhatsApp & Signal need no secrets (tokens auto-generate; pairing is via QR).

  # Telegram (re-enabled): needs API_ID/API_HASH in sops (`mautrix-telegram-env`).
  # "full" IS a valid permission level for Telegram (unlike whatsapp/signal).
  services.mautrix-telegram = {
    enable = true;
    environmentFile = config.sops.secrets."mautrix-telegram-env".path;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:${toString hsPort}";
        domain = domain;
      };
      # telegram's OWN appservice listener is :8080 (not the homeserver port).
      appservice.address = "http://127.0.0.1:${toString tgAppPort}";
      bridge.permissions = {
        "${domain}" = "full";
        "xsfx.dev" = "full";
      };
    };
  };

  services.mautrix-whatsapp = {
    enable = true;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:${toString hsPort}";
        domain = domain;
      };
      # appservice.address = the URL tuwunel pushes events TO = THIS bridge's own
      # HTTP listener (port 29318), NOT the homeserver port.
      appservice.address = "http://127.0.0.1:${toString waAppPort}";
      # "admin" (not "full") — mautrix WhatsApp only accept relay/user/admin.
      bridge.permissions = {
        "${domain}" = "admin";
        "xsfx.dev" = "admin";
      };
    };
  };

  services.mautrix-signal = {
    enable = true;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:${toString hsPort}";
        domain = domain;
      };
      # appservice.address = the URL tuwunel pushes events TO = THIS bridge's own
      # HTTP listener (port 29328), NOT the homeserver port.
      appservice.address = "http://127.0.0.1:${toString sgAppPort}";
      # "admin" (not "full") — mautrix Signal only accept relay/user/admin.
      bridge.permissions = {
        "${domain}" = "admin";
        "xsfx.dev" = "admin";
      };
    };
  };
}
