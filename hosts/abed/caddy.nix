{ pkgs, ... }:
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
        "github.com/daegalus/caddy-anubis@v0.0.0-20250423203506-a2bb6cdfacae"
        "github.com/mholt/caddy-ratelimit@v0.1.0"
        "pkg.jsn.cam/caddy-defender@v0.10.0"
      ];
      hash = "sha256-mv1LD+D+mJG5vmd4bvjbIlF/5ukRjQ0vFrDYYlwjPJk=";
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
          import badbots

          defender block {
            ranges aliyun vpn aws deepseek githubcopilot gcloud oci azurepubliccloud openai mistral vultr cloudflare digitalocean linode
          }

          reverse_proxy 127.0.0.1:3000
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
    };
  };
}
