{ inputs, ... }:
{
  imports = [
    ./configuration.nix
    ./cups.nix
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-3
    inputs.self.nixosModules.base
    inputs.self.nixosModules.ssh
    inputs.self.nixosModules.users
  ];
}
