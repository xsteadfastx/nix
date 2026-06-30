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
  piChannel = inputs.nixpkgs-unstable.legacyPackages.${system};

  # Pin pi to a specific release. overrideAttrs must replace `npmDeps`
  # itself, not just `npmDepsHash`: buildNpmPackage bakes `npmDeps` from the
  # original src at call time, so only bumping the hash would keep fetching
  # the previous version's lock and fail with a lockfile mismatch.
  piVersion = "0.80.2";
  piSrc = piChannel.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${piVersion}";
    hash = "sha256-aKtgPc3rwHEp856jP3N7nImph0CSG+gsWq9OVci3hmE=";
  };
in
{
  pi-coding-agent = piChannel.pi-coding-agent.overrideAttrs (_: {
    version = piVersion;
    src = piSrc;
    npmDeps = piChannel.fetchNpmDeps {
      src = piSrc;
      name = "pi-coding-agent-${piVersion}-npm-deps";
      hash = "sha256-1EGs8lX8XoAnRtS+pw4lBRm24U/vtVB2loVRmZyd4Z8=";
    };
  });

  inherit (piChannel)
    agent-browser
    mcp-nixos
    mcp-server-git
    mcp-grafana
    context7-mcp
    mcp-server-sequential-thinking
    ;
}
