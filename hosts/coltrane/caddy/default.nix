{ config, ... }:
{
  services.caddy = {
    enable = true;
    globalConfig = ''
      pki {
        ca local {
          root {
            cert ${./local-ca.crt}
            key ${config.sops.secrets."local-ca-key".path}
          }
        }
      }
    '';
    virtualHosts."paperless.local" = {
      extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:28981
      '';
    };
    virtualHosts."paperless-gpt.local" = {
      extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:8080
      '';
    };
  };

  networking.hosts."127.0.0.1" = [
    "paperless.local"
    "paperless-gpt.local"
  ];

  security.pki.certificateFiles = [ ./local-ca.crt ];

  programs.chromium.extraOpts = {
    CACertificates = builtins.readFile ./local-ca.crt;
  };
}
