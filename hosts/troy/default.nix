{ lib, ... }:
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./syncthing.nix
  ];

  virtualisation.vmVariant = {
    users.users.marv.initialPassword = "notsafe";
    # services.xserver.enable = lib.mkForce false;
    # services.xserver.windowManager.i3.enable = lib.mkForce false;
    xsfx.kodi = lib.mkForce false;
  };

  # dev stuff for chirpstack development
  networking.hosts = {
    "127.0.0.1" = [
      "chirpstack.localhost"
      "mqtt.localhost"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.allowedUDPPorts = [ 1700 ];
}
