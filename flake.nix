{
  description = "xsfx";

  inputs = {
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    airmtp.url = "github:xsteadfastx/airmtp";
    attic.url = "github:zhaofengli/attic";
    colmena.url = "github:zhaofengli/colmena";
    compose2nix.inputs.nixpkgs.follows = "nixpkgs";
    compose2nix.url = "github:aksiksi/compose2nix";
    disko.url = "github:nix-community/disko";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    kerouac.url = "git+ssh://git@git.wobcom.de/smartmetering/kerouac.git?ref=refs/tags/v0.12.8";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    pre-commit.url = "git+ssh://git@git.wobcom.de/smartmetering/pre-commit-nix.git";
    quickemu.inputs.nixpkgs.follows = "nixpkgs";
    quickemu.url = "github:quickemu-project/quickemu";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    srvos.url = "github:nix-community/srvos";
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
    in
    {
      colmena = import ./hive.nix { inherit inputs lib; };
      colmenaHive = inputs.colmena.lib.makeHive inputs.self.outputs.colmena;
      lib = import ./lib;
      nixosConfigurations = inputs.self.outputs.colmenaHive.nodes;
      nixosModules.base = import ./modules/base;
      nixosModules.home-manager = import ./modules/home-manager;
      nixosModules.ssh = import ./modules/ssh;
      nixosModules.tlsrouter = import ./modules/tlsrouter;
      nixosModules.users = import ./modules/users;
      nixosModules.vm-variant = import ./modules/vm-variant;
      overlays.default = import ./overlays { inherit inputs; };
    }
    // inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${system};

        preCommit = import ./pre-commit.nix {
          inherit (pkgsUnstable)
            nixfmt
            prek
            trufflehog
            yamlfmt
            ;
        };

        preCommitGen = inputs.pre-commit.lib.generate {
          inherit pkgs system;
          src = ./.;
          extra = preCommit;
          extraPackages = [
            inputs.agenix.packages.${system}.default
            inputs.colmena.packages.${system}.colmena
            inputs.nixos-anywhere.packages.${system}.default
            pkgs.sops
            pkgs.ssh-to-age
          ];
        };
      in
      {
        checks.pre-commit-check = preCommitGen.pre-commit-check;
        devShells.default = preCommitGen.devShell;
        formatter = preCommitGen.formatter;
        packages.phil-sdcard-img = import ./pkgs/phil-sdcard-img { inherit inputs; };
        packages.tlsrouter = pkgsUnstable.callPackage ./pkgs/tlsrouter/package.nix { };
      }
    );
}
