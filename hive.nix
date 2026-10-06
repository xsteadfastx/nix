{
  inputs,
  lib,
  ...
}:
{
  meta = {
    # Unstable packages are reached via `pkgs.unstable` (see overlays/default.nix),
    # so no separate pkgsUnstable specialArg is needed.
    specialArgs = {
      inherit inputs;
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
    deployment.tags = [
      "server"
      "vm"
    ];
    imports = [
      ./hosts/abed

      (inputs.self.lib.mkHetznerTinyVm "2a01:4f8:c0c:b07c::1/64")
      (inputs.self.lib.mkNodeExporter "100.113.26.112")
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
      inputs.fast-nix-gc.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.nixos-hardware.nixosModules.dell-xps-13-9350
      inputs.self.nixosModules.coding-agent
      inputs.self.nixosModules.home-manager
      inputs.self.nixosModules.lix
      inputs.self.nixosModules.ssh
      inputs.self.nixosModules.users
      inputs.self.nixosModules.vm-variant
      inputs.sops-nix.nixosModules.sops
    ];
  };

  dipper = {
    deployment.tags = [
      "server"
      "vm"
    ];
    imports = [
      ./hosts/dipper

      (inputs.self.lib.mkHetznerTinyVm "2a01:4f8:1c1c:1f0a::1/64")
      (inputs.self.lib.mkNodeExporter "100.124.197.13")
      inputs.disko.nixosModules.disko
      inputs.self.nixosModules.ssh
      inputs.self.nixosModules.tlsrouter
      inputs.self.nixosModules.users
      inputs.sops-nix.nixosModules.sops
      inputs.srvos.nixosModules.hardware-hetzner-cloud
      inputs.srvos.nixosModules.server
    ];
  };

  phil = {
    deployment.tags = [
      "server"
      "raspberrypi"
    ];
    imports = [
      ./hosts/phil
      inputs.nixos-hardware.nixosModules.raspberry-pi-3
      inputs.self.nixosModules.ssh
      inputs.self.nixosModules.users
      inputs.self.nixosModules.vm-variant
      inputs.srvos.nixosModules.server
    ];
  };
}
