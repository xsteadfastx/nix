{ inputs, ... }:
{
  imports = [
    ../../modules/ssh
    ../../modules/users
    ./configuration.nix
    ./cups.nix
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-3
  ];
}
