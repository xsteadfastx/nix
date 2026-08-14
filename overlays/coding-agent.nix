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
  # nixpkgs-unstable's pi-coding-agent (0.83.0) is older than the release we
  # want; pinning from GitHub keeps the bundled pi-permission-system
  # (peerDeps >=0.79.0) satisfied.
  piVersion = "0.84.1";
  piSrc = unstable.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${piVersion}";
    hash = "sha256-lg+I4S/aAjazjhGZU567ow+rksoNiqOqjHl//TjAMes=";
  };
in
{
  pi-coding-agent = unstable.pi-coding-agent.overrideAttrs (_: {
    version = piVersion;
    src = piSrc;
    npmDeps = unstable.fetchNpmDeps {
      src = piSrc;
      name = "pi-coding-agent-${piVersion}-npm-deps";
      hash = "sha256-tufyZQRPAUeDtiq0UQodbKA/Y9xUAvNT8K+NWFjkeME=";
    };
    # nixpkgs's modelData hash is for pi-ai-0.83.0.tgz; the URL follows
    # finalAttrs.version, so it must be re-pinned for the new version.
    modelData = unstable.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${piVersion}.tgz";
      hash = "sha256-araJGJ58s95c2xJjEqPmDorDX+XuXxtj0A9xHIpDDHM=";
    };
  });

  inherit (unstable) claude-code;

  # Most popular postgres MCP; built from source (not in nixpkgs) against the
  # unstable python set so its deps match the versions checked in pkgs file.
  postgres-mcp = unstable.callPackage ../pkgs/postgres-mcp.nix { };

  # Confluence/Jira MCP (sooperset/mcp-atlassian) + its hard dep
  # markdown-to-confluence (hunyadi/md2conf); both built from source (not in
  # nixpkgs) against the unstable python set.
  mcp-atlassian = unstable.callPackage ../pkgs/mcp-atlassian.nix {
    markdown-to-confluence = unstable.callPackage ../pkgs/markdown-to-confluence.nix { };
  };

  # Official Redis MCP (redis/mcp-redis) + its hard dep redis-entraid; both
  # built from source (not in nixpkgs) against the unstable python set.
  redis-mcp-server = unstable.callPackage ../pkgs/redis-mcp.nix {
    redis-entraid = unstable.callPackage ../pkgs/redis-entraid.nix { };
  };

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
