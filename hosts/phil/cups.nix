{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    listenAddresses = [
      "0.0.0.0:631"
    ];
    allowFrom = [ "@LOCAL" ];
    browsing = true;
    drivers = with pkgs; [
      brlaser
    ];
  };
  networking.firewall.allowedTCPPorts = [ 631 ];
  networking.firewall.allowedUDPPorts = [
    5353
  ];
  services.avahi = {
    enable = true;
    publish = {
      enable = true;
    };
  };
}
