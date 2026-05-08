{ ... }:
{
  services.smokeping = {
    enable = true;
    hostName = "localhost";
    targetConfig = ''
      probe = FPing

      menu = Top
      title = Network Latency

      + Cloudflare
      menu = Cloudflare
      title = Cloudflare 1.1.1.1
      host = 1.1.1.1

      + InternalDNS
      menu = Internal DNS
      title = Internal DNS 192.168.39.120
      host = 192.168.39.120

      + NixosCache
      menu = cache.nixos.org
      title = cache.nixos.org
      host = cache.nixos.org
    '';
  };

  services.nginx.virtualHosts.smokeping.listen = [
    {
      addr = "127.0.0.1";
      port = 8080;
    }
  ];
}
