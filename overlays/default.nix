{ inputs, ... }:
final: prev: {
  # needed because there is a system gpg-agent and gpg from wrapped gopass mismatch
  gopass = prev.gopass.overrideAttrs rec {
    wrapperPath = prev.lib.makeBinPath (
      [
        prev.git
        prev.xclip
      ]
      ++ prev.lib.optional prev.stdenv.isLinux prev.wl-clipboard
    );
    postFixup = ''
      wrapProgram $out/bin/gopass \
        --prefix PATH : "${wrapperPath}" \
        --set GOPASS_NO_REMINDER true
    '';
  };

  localsend-go = prev.callPackage ../pkgs/localsend-go.nix { };

  airmtp = inputs.airmtp.packages.${prev.system}.default;

  compose2nix = inputs.compose2nix.packages.${prev.system}.default;

  bumblebee-status = prev.bumblebee-status.override {
    plugins = p: [
      p.cpu
      p.nic
      p.pipewire
    ];
  };

  quickemu = inputs.quickemu.packages.${prev.system}.default;

  imagingedge4linux = prev.callPackage ../pkgs/imagingedge4linux/package.nix { };
  importsony = prev.callPackage ../pkgs/importsony/package.nix { };
  importsony-jpegs = prev.callPackage ../pkgs/importsony-jpegs/package.nix { };

  xsaneGimp = prev.xsane.override { gimpSupport = true; };

  kerouac = inputs.kerouac.packages.${prev.system}.kerouacLinuxAmd64;

  attic = inputs.attic.packages.${prev.system}.attic;

  meshcore-cli = prev.callPackage ../pkgs/meshcore-cli/package.nix { };
}
