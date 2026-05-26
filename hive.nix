{
  inputs,
  lib,
  ...
}:
{
  meta = {
    specialArgs = {
      inherit inputs;
      pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages;
    };
    nixpkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
    };
  };

  defaults =
    { config, ... }:
    {
      deployment.targetUser = null;
      deployment.targetHost = config.networking.hostName;

      imports = [ inputs.self.nixosModules.base ];
    };

  abed = {
    deployment.tags = [ "server" ];
    imports = [
      ./hosts/abed

      (inputs.self.lib.exporters.mkNodeExporter "100.113.26.112")
      inputs.disko.nixosModules.disko
      inputs.self.nixosModules.ssh
      inputs.self.nixosModules.users
      inputs.self.nixosModules.vm-variant
      inputs.sops-nix.nixosModules.sops
      inputs.srvos.nixosModules.hardware-hetzner-cloud
      inputs.srvos.nixosModules.server
    ];
  };

  coltrane = {
    deployment.tags = [ "local" ];
    deployment.allowLocalDeployment = true;
    deployment.targetHost = lib.mkForce null;
    imports = [
      ./hosts/coltrane

      inputs.disko.nixosModules.disko
      inputs.home-manager.nixosModules.home-manager
      inputs.nixos-hardware.nixosModules.dell-xps-13-9350
      inputs.self.nixosModules.home-manager
      inputs.self.nixosModules.ssh
      inputs.self.nixosModules.users
      inputs.self.nixosModules.vm-variant
    ];
  };

  dipper = {
    deployment.tags = [ "server" ];
    imports = [
      ./hosts/dipper

      (inputs.self.lib.exporters.mkNodeExporter "100.124.197.13")
      inputs.disko.nixosModules.disko
      inputs.self.nixosModules.ssh
      inputs.self.nixosModules.tlsrouter
      inputs.self.nixosModules.users
      inputs.srvos.nixosModules.hardware-hetzner-cloud
      inputs.srvos.nixosModules.server
    ];
  };

  phil = {
    deployment.tags = [ "server" ];
    imports = [
      ./hosts/phil

      inputs.nixos-hardware.nixosModules.raspberry-pi-3
      inputs.self.nixosModules.ssh
      inputs.self.nixosModules.users
      inputs.srvos.nixosModules.server
    ];
  };

  troy = {
    deployment.tags = [ "local" ];
    deployment.allowLocalDeployment = true;
    deployment.targetHost = lib.mkForce null;
    imports = [
      ./hosts/troy

      inputs.home-manager.nixosModules.home-manager
      inputs.nixos-hardware.nixosModules.dell-xps-13-7390
      inputs.self.nixosModules.home-manager
      inputs.self.nixosModules.users
    ];
  };
}
