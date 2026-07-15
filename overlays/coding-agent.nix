# Overlay that sources the coding-agent's runtime packages from
# nixpkgs-unstable so the portable module (modules/coding-agent) can reference
# them as plain pkgs.* attrs without depending on a pkgsUnstable specialArg.
#
# All unstable packages come from the single central `pkgs.unstable` instance
# (allowUnfree) created by overlays/default.nix, reached via the overlay's
# `final` fixed-point. This file does NOT import nixpkgs-unstable itself — one
# import for the whole repo, no per-overlay eval. No recursion: pkgs.unstable's
# import (in overlays/default.nix) does not depend on this overlay's outputs.
# Requires overlays.default to be applied alongside (modules/base does so).
final: _prev:
let
  unstable = final.unstable;

  # Pin pi to a specific release. overrideAttrs must replace `npmDeps`
  # itself, not just `npmDepsHash`: buildNpmPackage bakes `npmDeps` from the
  # original src at call time, so only bumping the hash would keep fetching
  # the previous version's lock and fail with a lockfile mismatch.
  piVersion = "0.80.3";
  piSrc = unstable.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${piVersion}";
    hash = "sha256-wQTrWKsb2HCGwzSAFEk8NWSDpqxSY/lv1/R6ghcmbaA=";
  };
in
{
  pi-coding-agent = unstable.pi-coding-agent.overrideAttrs (_: {
    version = piVersion;
    src = piSrc;
    npmDeps = unstable.fetchNpmDeps {
      src = piSrc;
      name = "pi-coding-agent-${piVersion}-npm-deps";
      hash = "sha256-geh8LH88OZybFXkR/jDeTdew6TNMdFM6jhCSYKn//dU=";
    };
  });

  inherit (unstable) claude-code;

  inherit (unstable)
    agent-browser
    mcp-nixos
    mcp-server-git
    mcp-grafana
    github-mcp-server
    context7-mcp
    mcp-server-sequential-thinking
    mcp-server-memory
    playwright-mcp
    mcp-proxy
    github-cli
    ripgrep
    ;
}
