{ inputs, ... }:

# Overlay that sources the coding-agent's runtime packages from
# nixpkgs-unstable so the portable module (modules/coding-agent) can reference
# them as plain pkgs.* attrs without depending on a pkgsUnstable specialArg.
# The overlay closes over this flake's inputs, so third parties applying it get
# the same pinned versions; consumers not applying it fall back to their own
# nixpkgs.
prev:
let
  system = prev.stdenv.hostPlatform.system;

  # The free agent packages: reuse the unstable channel's *already-evaluated*
  # legacyPackages instead of a second `import`. This shares the eval the flake
  # already does for nixpkgs-unstable rather than spinning up a fresh nixpkgs.
  unstable = inputs.nixpkgs-unstable.legacyPackages.${system};

  # claude-code is unfree, and legacyPackages is pre-evaluated upstream with
  # allowUnfree = false (uneditable), so it alone needs a scoped `import`.
  # allowUnfreePredicate limits the exception to claude-code — not a blanket
  # allowUnfree over the whole tree.
  unstableUnfree = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfreePredicate = p: prev.lib.getName p == "claude-code";
  };

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

  inherit (unstableUnfree) claude-code;

  inherit (unstable)
    agent-browser
    mcp-nixos
    mcp-server-git
    mcp-grafana
    context7-mcp
    mcp-server-sequential-thinking
    mcp-server-memory
    playwright-mcp
    mcp-proxy
    github-cli
    ripgrep
    ;
}
