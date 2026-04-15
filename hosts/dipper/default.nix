{
  inputs,
  ...
}:
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    inputs.self.nixosModules.users
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.server
  ];
}
