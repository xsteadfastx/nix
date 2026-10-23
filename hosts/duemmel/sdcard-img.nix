{ inputs, ... }:
# The SD image is the deployed configuration plus the sd-card module — not a
# second, independently-built system. Same pkgs instance, same module set, so
# `colmena apply` and `nix build .#duemmel-sdcard-img` share one closure.
(inputs.self.nixosConfigurations.duemmel.extendModules {
  modules = [ "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix" ];
}).config.system.build.sdImage
