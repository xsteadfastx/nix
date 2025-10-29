{ inputs, ... }:
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];
}
