{
  inputs,
  ...
}:
{
  imports = [
    (inputs.self.lib.exporters.mkNodeExporter "100.124.197.13")
    ./configuration.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./network.nix
    ./tlsrouter.nix
    inputs.disko.nixosModules.disko
    inputs.self.nixosModules.base
    inputs.self.nixosModules.ssh
    inputs.self.nixosModules.tlsrouter
    inputs.self.nixosModules.users
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.server
  ];
}
