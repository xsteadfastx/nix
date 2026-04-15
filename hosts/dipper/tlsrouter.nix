{ inputs, pkgs, ... }:
{
  services.tlsrouter = {
    enable = true;
    package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.tlsrouter;
    routes = {
      "sonic.xsfx.name".backend = "lorelei.ts.xsfx.dev:443";
      # "grafik.amsel-kaffee.de".backend = "lorelei.ts.xsfx.dev:443";
    };
  };
  networking.firewall.allowedTCPPorts = [ 443 ];
}
