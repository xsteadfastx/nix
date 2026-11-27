# Our packages. Added to pkgs by overlays/additions.nix and exposed as flake
# `packages`.
pkgs: {
  localsend-go = pkgs.callPackage ./localsend-go.nix { };

  # ESP32-C5 ITS-G5 -> MQTT bridge for the duemmel receiver (hosts/duemmel).
  its-g5-bridge = pkgs.callPackage ./its-g5-bridge { };

  # Go (bridgev2) mautrix-telegram, shadows nixpkgs' legacy Python one. Builds
  # against cgo libolm (olm-3.2.16) — only on hosts that permit it (dipper does).
  mautrix-telegram = pkgs.callPackage ./mautrix-telegram.nix { };

  meshtui = pkgs.python3Packages.callPackage ./meshtui/package.nix { };
  meshtui2 = pkgs.python3Packages.callPackage ./meshtui2/package.nix { };
  meshy = pkgs.callPackage ./meshy/package.nix { };
  lilium-voyager = pkgs.callPackage ./lilium-voyager.nix { };
  jetbrains-mono-nerd = pkgs.callPackage ./jetbrains-mono-nerd/package.nix { };
  imagingedge4linux = pkgs.callPackage ./imagingedge4linux/package.nix { };
  importsony = pkgs.callPackage ./importsony/package.nix { };
  importsony-jpegs = pkgs.callPackage ./importsony-jpegs/package.nix { };
  paperless-mcp = pkgs.callPackage ./paperless-mcp/package.nix { };
  zettelrobbe = pkgs.callPackage ./zettelrobbe/package.nix { };
  calibre-dedrm-plugin = pkgs.callPackage ./calibre-dedrm-plugin/package.nix { };
  calibre-deacsm-plugin = pkgs.callPackage ./calibre-deacsm-plugin/package.nix { };

  # only nixpkgs-unstable has pkgsCross.wasm32-wasip1 (needed for the wasm build)
  zellij-ssh-tint = pkgs.unstable.callPackage ./zellij-ssh-tint/package.nix { };
}
