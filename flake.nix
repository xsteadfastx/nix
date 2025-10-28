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
    firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    kerouac.url = "git+ssh://git@git.wobcom.de/smartmetering/kerouac.git?ref=refs/tags/v0.12.8";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
    quickemu.inputs.nixpkgs.follows = "nixpkgs";
    quickemu.url = "github:quickemu-project/quickemu";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs.lib;
    in
    {
      colmenaHive = inputs.colmena.lib.makeHive inputs.self.outputs.colmena;
      nixosConfigurations = inputs.self.outputs.colmenaHive.nodes;
      colmena = import ./hive.nix { inherit inputs lib; };

      overlays.default = import ./overlays { inherit inputs; };
    }
    // inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${system};

        inherit (pkgs) mkShell;

        preCommit = import ./pre-commit.nix {
          inherit (pkgsUnstable) trufflehog yamlfmt nixfmt-rfc-style;
        };

        treefmtEval = inputs.treefmt-nix.lib.evalModule pkgsUnstable ./treefmt.nix;
      in
      {
        devShells = {
          default = mkShell {
            buildInputs = [
              inputs.agenix.packages.${system}.default
              inputs.colmena.packages.${system}.colmena
            ];
            inherit (inputs.self.checks.${system}.pre-commit-check) shellHook;
          };
        };

        checks = {
          pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run preCommit;
          formatting = treefmtEval.config.build.check inputs.self;
        };

        formatter = treefmtEval.config.build.wrapper;
      }
    );
}
