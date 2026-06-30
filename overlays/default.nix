{ inputs, ... }:

# Nix overlay for custom packages
# Provides overrides and additional packages used by the system.
# Maintainer: Marvin Preuss <marv@yourdomain.com>

_: prev:
let
  system = prev.stdenv.hostPlatform.system;
  # coding-agent runtime packages (pinned/sourced from nixpkgs-unstable).
  codingAgent = import ./coding-agent.nix { inherit inputs; };
in
(codingAgent prev)
// {
  localsend-go = prev.callPackage ../pkgs/localsend-go.nix { };

  airmtp = inputs.airmtp.packages.${system}.default;
  compose2nix = inputs.compose2nix.packages.${system}.default;

  bumblebee-status = prev.bumblebee-status.override {
    # Add the plugins we actually use in this configuration.
    plugins = p: [
      p.cpu
      p.nic
      p.pipewire
    ];
  };

  quickemu = inputs.quickemu.packages.${system}.default;

  imagingedge4linux = prev.callPackage ../pkgs/imagingedge4linux/package.nix { };
  importsony = prev.callPackage ../pkgs/importsony/package.nix { };
  importsony-jpegs = prev.callPackage ../pkgs/importsony-jpegs/package.nix { };
  paperless-gpt = prev.callPackage ../pkgs/paperless-gpt/package.nix { };

  xsaneGimp = prev.xsane.override { gimpSupport = true; };

  kerouac = inputs.kerouac.packages.${system}.kerouacLinuxAmd64;
  attic = inputs.attic.packages.${system}.attic;

  cliamp = prev.cliamp.overrideAttrs (rec {
    version = "1.57.0";
    src = prev.fetchFromGitHub {
      owner = "bjarneo";
      repo = "cliamp";
      tag = "v${version}";
      hash = "sha256-tfPtc+YgtmuzdWod6EM0MJSoYLxLnQskuNRQbLRp4g8=";
    };
    vendorHash = "sha256-A2Ygc1a9e2flZzaNAEXvr8Ui1cE89TxBfUNALmDzIo0=";
    meta = {
      description = "CLI amp – a simple audio volume controller for the terminal";
      homepage = "https://github.com/bjarneo/cliamp";
      license = prev.lib.licenses.mit;
      maintainers = with prev.lib.maintainers; [ marv ];
    };
  });
}
