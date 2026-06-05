{ config, ... }:
{
  services.caddy = {
    enable = true;
    globalConfig = ''
      pki {
        ca local {
          root {
            format pem_file
            cert ${./local-ca.crt}
            key ${config.sops.secrets."local-ca-key".path}
          }
          intermediate {
            format pem_file
            cert ${./local-intermediate.crt}
            key ${config.sops.secrets."local-intermediate-key".path}
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

  environment.etc."chromium/policies/managed/local-ca.json".text = builtins.toJSON {
    CACertificates = [ (builtins.readFile ./local-ca.crt) ];
  };
}
