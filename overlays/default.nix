{ inputs, ... }:

# Nix overlay for custom packages
# Provides overrides and additional packages used by the system.
# Maintainer: Marvin Preuss <marv@yourdomain.com>

_: prev:
let
  system = prev.stdenv.hostPlatform.system;
in
{
  # `gh` wrapper that authenticates from the sops-decrypted token file at
  # runtime. /run/secrets/gh-token is provisioned by sops-nix only on hosts
  # that declare sops.secrets."gh-token" (see hosts/coltrane/secrets.nix); on
  # hosts without it the file is absent, this is a no-op, and `gh` runs as-is
  # (its own auth, or unauthenticated). Reading the file at exec time keeps
  # the secret out of the nix store and picks up rotated tokens on the next
  # call. This is a separate wrapper package (not an override of `github-cli`)
  # that ships a `bin/gh`; it is added to the user's home.packages
  # (home-manager/modules/base.nix), so it lands on the shell PATH and the
  # coding agent inherits it from there. `github-cli` itself is left untouched
  # (keeping its completions/man pages) and is deliberately not on PATH, so
  # this wrapper is the only `gh`.
  githubCliTokenWrapped = prev.writeShellScriptBin "gh" ''
    if [ -f /run/secrets/gh-token ]; then
      export GH_TOKEN=$(cat /run/secrets/gh-token)
    fi
    exec ${prev.github-cli}/bin/gh "$@"
  '';

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

  # MediaElch 2.12.0 ships a TMDB scraper bug: a query parameter is added
  # twice (once via getMovieSearchUrl's 3rd arg, once via the UrlParameterMap).
  # TMDB rejects duplicate params with HTTP 400, surfacing as
  # "Network Error: Could not load the requested resource".
  # Upstream fix: Komet/MediaElch commit f68419e (PR #1995, issue #1992).
  # Remove this override once nixpkgs ships a MediaElch version > 2.12.0.
  mediaelch = prev.mediaelch.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (prev.fetchpatch {
        name = "fix-tmdb-duplicate-query-param.patch";
        url = "https://github.com/Komet/MediaElch/commit/f68419e746455d3c7eb6d95a4a1da7a6f7a5c505.patch";
        hash = "sha256-u+ScJDFX2IIpjXV58MCp1uJGx9QU+7cbq+e1qZPMWns=";
      })
    ];
  });

  kerouac = inputs.kerouac.packages.${system}.kerouacLinuxAmd64;
  attic = inputs.attic.packages.${system}.attic;

  cliamp = prev.cliamp.overrideAttrs (rec {
    version = "1.57.1";
    src = prev.fetchFromGitHub {
      owner = "bjarneo";
      repo = "cliamp";
      tag = "v${version}";
      hash = "sha256-wRXF2bnl3xFJtuESJX2UVSsPwl4xo6E+k7nIdtzCULo=";
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
