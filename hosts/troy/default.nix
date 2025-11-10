{
  inputs,
  ...
}:
{
  imports = [
    ../../modules/home-manager
    ../../modules/users
    ./chromium.nix
    ./configuration.nix
    ./hardware-configuration.nix
    ./syncthing.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-hardware.nixosModules.dell-xps-13-7390
  ];
}
