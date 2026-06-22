{ inputs, ... }:
_final: prev: {
  localsend-go = prev.callPackage ../pkgs/localsend-go.nix { };

  airmtp = inputs.airmtp.packages.${prev.stdenv.hostPlatform.system}.default;

  compose2nix = inputs.compose2nix.packages.${prev.stdenv.hostPlatform.system}.default;

  bumblebee-status = prev.bumblebee-status.override {
    plugins = p: [
      p.cpu
      p.nic
      p.pipewire
    ];
  };

  quickemu = inputs.quickemu.packages.${prev.stdenv.hostPlatform.system}.default;

  imagingedge4linux = prev.callPackage ../pkgs/imagingedge4linux/package.nix { };
  importsony = prev.callPackage ../pkgs/importsony/package.nix { };
  importsony-jpegs = prev.callPackage ../pkgs/importsony-jpegs/package.nix { };
  paperless-gpt = prev.callPackage ../pkgs/paperless-gpt/package.nix { };

  xsaneGimp = prev.xsane.override { gimpSupport = true; };

  kerouac = inputs.kerouac.packages.${prev.stdenv.hostPlatform.system}.kerouacLinuxAmd64;

  attic = inputs.attic.packages.${prev.stdenv.hostPlatform.system}.attic;

  # meshcore-cli = prev.callPackage ../pkgs/meshcore-cli/package.nix { };
  # meshcore-web = prev.callPackage ../pkgs/meshcore-web/package.nix { };

  cliamp = prev.cliamp.overrideAttrs (_oldAttrs: rec {
    version = "1.57.0";
    src = prev.fetchFromGitHub {
      owner = "bjarneo";
      repo = "cliamp";
      tag = "v${version}";
      hash = "sha256-tfPtc+YgtmuzdWod6EM0MJSoYLxLnQskuNRQbLRp4g8=";
    };
    vendorHash = "sha256-A2Ygc1a9e2flZzaNAEXvr8Ui1cE89TxBfUNALmDzIo0=";
  });
}
