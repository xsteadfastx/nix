{ lib, inputs, ... }:
{
  imports = [
    ../../modules/home-manager
    ./configuration.nix
    ./hardware-configuration.nix
    ./syncthing.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-hardware.nixosModules.dell-xps-13-7390
  ];

  xsfx.kodi = true;
  xsfx.neovim = true;
  xsfx.work = true;
  xsfx.x11 = true;

  home-manager.users.marv = import ../../home-manager/marv.nix;

  virtualisation.vmVariant = {
    users.users.marv.initialPassword = "notsafe";
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
