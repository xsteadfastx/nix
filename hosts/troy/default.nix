{
  inputs,
  ...
}:
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./syncthing.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-hardware.nixosModules.dell-xps-13-7390
    inputs.self.nixosModules.home-manager
    inputs.self.nixosModules.users
  ];
}
