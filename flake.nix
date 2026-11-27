{
  description = "xsfx";

  inputs = {
    airmtp.inputs.nixpkgs.follows = "nixpkgs";
    airmtp.url = "github:xsteadfastx/airmtp";
    attic.url = "github:zhaofengli/attic";
    catppuccin-claude-code.flake = false;
    catppuccin-claude-code.url = "github:vishwajitsarnobat/catppuccin-claude-code";
    catppuccin-pi.flake = false;
    catppuccin-pi.url = "github:XYenon/catppuccin-pi-coding-agent";
    catppuccin-userstyles.flake = false;
    catppuccin-userstyles.url = "github:catppuccin/userstyles";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url = "github:catppuccin/nix/release-26.05";
    christine-preuss-de.inputs.nixpkgs.follows = "nixpkgs-unstable";
    christine-preuss-de.url = "github:xsteadfastx/christine-preuss.de";
    coding-agent.inputs.home-manager.follows = "home-manager";
    coding-agent.url = "git+https://git.xsfx.dev/xsteadfastx/coding-agent.git";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
    colmena.url = "github:zhaofengli/colmena";
    compose2nix.inputs.nixpkgs.follows = "nixpkgs";
    compose2nix.url = "github:aksiksi/compose2nix";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    fast-nix-gc.inputs.nixpkgs.follows = "nixpkgs";
    fast-nix-gc.url = "github:Mic92/fast-nix-gc";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpak.url = "github:nixpak/nixpak";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    pre-commit.inputs.pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs-unstable";
    pre-commit.url = "git+https://git.xsfx.dev/xsteadfastx/pre-commit-nix.git";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    srvos.inputs.nixpkgs.follows = "nixpkgs";
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
      nixosModules.coding-agent = inputs.coding-agent.nixosModules.coding-agent-raw;
      nixosModules.home-manager = import ./modules/home-manager;
      nixosModules.lix = import ./modules/lix;
      nixosModules.ssh = import ./modules/ssh;
      # from nixpkgs-unstable: the pinned nixpkgs predates the module/package
      nixosModules.tlsrouter = import "${inputs.nixpkgs-unstable}/nixos/modules/services/networking/tlsrouter.nix";
      nixosModules.users = import ./modules/users;
      nixosModules.vm-variant = import ./modules/vm-variant;
      overlays.default = import ./overlays { inherit inputs; };
    }
    // inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        # import (not legacyPackages) so we can set `permittedInsecurePackages`:
        # packages.mautrix-telegram links libolm (olm-3.2.16), which nixpkgs marks
        # insecure. Deploy hosts already permit it via nixpkgs.config. This keeps
        # `nix flake check` (which builds every packages.*) from failing. Exactly
        # equivalent to legacyPackages otherwise.
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.permittedInsecurePackages = [ "olm-3.2.16" ];
        };
        pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${system};

        # the pkgs/ packages, built against the same overlaid set the hosts get
        additions = import ./pkgs (pkgs.extend (import ./overlays { inherit inputs; }));

        preCommit = import ./pre-commit.nix {
          inherit (pkgs) convco;
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
            inputs.colmena.packages.${system}.colmena
            inputs.nixos-anywhere.packages.${system}.default
            pkgs.sops
            pkgs.ssh-to-age
          ];
        };
      in
      {
        checks.pre-commit-check = preCommitGen.pre-commit-check;
        # Extract-and-derive logic of the paperless enrichment script, run against
        # the shipped extractor table with fixtures taken from real documents.
        checks.paperless-enrich = pkgs.runCommand "paperless-enrich-self-test" { } ''
          cp ${./hosts/coltrane/paperless/paperless-enrich.py} paperless-enrich.py
          cp ${./hosts/coltrane/paperless/extractors.json} extractors.json
          ${pkgs.python3}/bin/python3 paperless-enrich.py --self-test
          touch $out
        '';
        devShells.default = preCommitGen.devShell;
        inherit (preCommitGen) formatter;
        packages = additions // {
          phil-sdcard-img = import ./pkgs/phil-sdcard-img { inherit inputs; };
          duemmel-sdcard-img = import ./hosts/duemmel/sdcard-img.nix { inherit inputs; };
        };
      }
    );
}
