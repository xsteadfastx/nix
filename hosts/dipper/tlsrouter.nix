{ pkgs, ... }:
{
  services.tlsrouter = {
    enable = true;
    package = pkgs.unstable.tlsrouter;
    routes = {
      "sonic.xsfx.name".backend = "lorelei.ts.xsfx.dev:443";
    };
  };
  networking.firewall.allowedTCPPorts = [ 443 ];
}
