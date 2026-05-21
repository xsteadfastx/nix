{ inputs, ... }:
let
  system = "aarch64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [
      (_final: super: {
        makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
      })
    ];
  };
in
(inputs.nixpkgs.lib.nixosSystem {
  inherit system pkgs;
  modules = [
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    ../../hosts/phil
  ];
  specialArgs = {
    lib = pkgs.lib;
    inherit inputs;
  };
}).config.system.build.sdImage
