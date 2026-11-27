{ pkgs, inputs, ... }:
{
  networking.firewall.allowedTCPPorts = [
    443
    80
  ];

  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [
        "github.com/caddyserver/cache-handler@v0.16.0"
        "github.com/caddyserver/transform-encoder@v0.0.0-20260403095929-3a808ce84ca0"
        "github.com/mholt/caddy-ratelimit@v0.1.0"
        "pkg.jsn.cam/caddy-defender@v0.10.0"
      ];
      hash = "sha256-e4Pgz4avhpeYunT7CiCaThPdd0y5fVdTJDatc9LECzc=";
    };

    globalConfig = ''
      admin 0.0.0.0:2019
      acme_ca https://acme-v02.api.letsencrypt.org/directory
      email marv@xsfx.dev
      cache
      servers {
        metrics
      }
    '';

    extraConfig = ''
      # Anubis (PoW anti-scraper) in front of Forgejo on :3000 (see
      # hosts/abed/anubis.nix). X-Real-IP so Anubis sees the real client, not
      # the loopback address.
      (anubis) {
        reverse_proxy 127.0.0.1:8923 {
          header_up X-Real-IP {remote_host}
        }
      }

      (badbots) {
        @badbots {
          header User-Agent *AhrefsBot*
          header User-Agent *Amazonbot*
          header User-Agent *BLEXBot*
          header User-Agent *Barkrowler*
          header User-Agent *Bytespider*
          header User-Agent *ClaudeBot*
          header User-Agent *DataForSeoBot*
          header User-Agent *GPTBot*
          header User-Agent *ImagesiftBot*
          header User-Agent *MJ12bot*
          header User-Agent *PetalBot*
          header User-Agent *SemrushBot*
          header User-Agent *facebookexternalhit*
          header User-Agent *meta-externalagent*
          header User-Agent *bingbot*
        }
        abort @badbots
      }
    '';

    virtualHosts = {
      "git.xsfx.dev" = {
        extraConfig = ''
          # route keeps this order; bare, Caddy would sort the handles ahead of
          # the badbots abort.
          route {
            import badbots

            # Read-only git fetches skip the IP blocklist: GitHub Actions runners
            # come from AWS and Azure and fetch this repo's flake inputs from
            # here. Pushes (git-receive-pack) and the web UI stay blocked.
            @gitfetch expression path('*/git-upload-pack') || (path('*/info/refs') && {query.service} == 'git-upload-pack')
            handle @gitfetch {
              import anubis
            }
            handle {
              defender block {
                ranges aliyun vpn aws deepseek githubcopilot gcloud oci azurepubliccloud openai mistral vultr cloudflare digitalocean linode
              }
              import anubis
            }
          }
        '';
      };

      "go.xsfx.dev" = {
        extraConfig = ''
          route /* {
            @goget query go-get=1
            respond @goget `<meta name="go-import" content="{host}{path} git https://git.xsfx.dev/xsteadfastx{path}">`
            redir https://git.xsfx.dev/xsteadfastx{path}
          }
        '';
      };

      "www.christine-preuss.de" = {
        extraConfig = ''
          redir https://christine-preuss.de{uri} permanent
        '';
      };

      "christine-preuss.de" = {
        extraConfig = ''
          root * ${inputs.christine-preuss-de.packages.${pkgs.stdenv.hostPlatform.system}.default}
          file_server
        '';
      };
    };
  };
}
