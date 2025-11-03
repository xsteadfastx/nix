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
inputs.nixos-generators.nixosGenerate {
  inherit system pkgs;
  format = "sd-aarch64";
  modules = [
    ../../hosts/phil
  ];
  specialArgs = {
    lib = pkgs.lib;
    inherit inputs;
  };
}
