{
  inputs,
  ...
}:
{
  imports = [
    ./configuration.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./network.nix
    ./tlsrouter.nix
    inputs.disko.nixosModules.disko
    inputs.self.nixosModules.tlsrouter
    inputs.self.nixosModules.users
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.server
  ];
}
