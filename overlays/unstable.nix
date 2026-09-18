{
  inputs,
  packageOverrides,
  codingAgent,
  ...
}:

# Factory: given the custom-package overlay (`packageOverrides`) and the
# coding-agent data (`codingAgent`), expose a single nested nixpkgs-unstable
# instance as `pkgs.unstable`. Importing a second channel once, centrally, is
# the idiomatic way to mix channels — it avoids the "1000 instances of
# nixpkgs" antipattern of scattering `import nixpkgs-unstable {...}` across
# modules. Reachable anywhere `pkgs` is (system and, via useGlobalPkgs,
# home-manager) as `pkgs.unstable.<name>`.
#
# `import` (not `.legacyPackages`) is required for `allowUnfree`; the same
# packageOverrides are applied so custom packages resolve identically on both
# channels (`pkgs.foo` = stable, `pkgs.unstable.foo` = unstable). The
# coding-agent repo's overlay is applied here too, so the Python MCP servers
# build against unstable (recent deps).
_final: prev: {
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
    overlays = [
      packageOverrides
      codingAgent.codingAgentOverlay
    ];
  };
}
