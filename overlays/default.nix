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

  xsaneGimp = prev.xsane.override { gimpSupport = true; };

  kerouac = inputs.kerouac.packages.${prev.stdenv.hostPlatform.system}.kerouacLinuxAmd64;

  attic = inputs.attic.packages.${prev.stdenv.hostPlatform.system}.attic;

  # meshcore-cli = prev.callPackage ../pkgs/meshcore-cli/package.nix { };
  # meshcore-web = prev.callPackage ../pkgs/meshcore-web/package.nix { };

  yt-dlp = prev.yt-dlp.overrideAttrs (_oldAttrs: rec {
    version = "2026.03.17";
    src = prev.fetchFromGitHub {
      owner = "yt-dlp";
      repo = "yt-dlp";
      tag = version;
      hash = "sha256-A4LUCuKCjpVAOJ8jNoYaC3mRCiKH0/wtcsle0YfZyTA=";
    };
  });

  cliamp = prev.cliamp.overrideAttrs (_oldAttrs: rec {
    version = "1.34.1";
    src = prev.fetchFromGitHub {
      owner = "bjarneo";
      repo = "cliamp";
      tag = "v${version}";
      hash = "sha256-nhgdM0C+QgvTdXLrbo0DNJPVhqaumQgNBd3bmiwDk8M=";
    };
    vendorHash = "sha256-sS0tjZoZ81Jwn/KJnJD01fTA4z0HxEYYM89Ta398MP0=";
  });
}
