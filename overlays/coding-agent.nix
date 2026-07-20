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
  piVersion = "0.80.10";
  piSrc = unstable.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${piVersion}";
    hash = "sha256-Vs/ndHYzFyfN4CjPV2zMYblLXe9IuM13UrPJI1VsZEQ=";
  };
in
{
  pi-coding-agent = unstable.pi-coding-agent.overrideAttrs (_: {
    version = piVersion;
    src = piSrc;
    npmDeps = unstable.fetchNpmDeps {
      src = piSrc;
      name = "pi-coding-agent-${piVersion}-npm-deps";
      hash = "sha256-XGvDNH+eilsgc0Z7ITqbitB/9RVc+WuDfCcr1pibNqk=";
    };
  });

  inherit (unstable) claude-code;

  # Most popular postgres MCP; built from source (not in nixpkgs) against the
  # unstable python set so its deps match the versions checked in pkgs file.
  postgres-mcp = unstable.callPackage ../pkgs/postgres-mcp.nix { };

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
