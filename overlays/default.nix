{
  inputs,
  ...
}:
# Nix overlay for custom packages. A thin coordinator that composes the
# per-concern overlay files below (via lib.composeManyExtensions); adding a new
# concern is just another file plus one entry here.
#
#   package-overrides.nix  custom packages
#   unstable.nix           the nested nixpkgs-unstable instance (pkgs.unstable)
#   nixpak.nix             bubblewrap-sandboxed work apps
#   coding-agent.nix .overlay  surface unstable coding-agent packages at top level
#
# Maintainer: Marvin Preuss <marv@yourdomain.com>
let
  packageOverrides = import ./package-overrides.nix { inherit inputs; };
  codingAgent = import ./coding-agent.nix { inherit inputs; };
  unstable = import ./unstable.nix {
    inherit inputs packageOverrides codingAgent;
  };
  nixpak = import ./nixpak.nix { inherit inputs; };
in
inputs.nixpkgs.lib.composeManyExtensions [
  packageOverrides
  unstable
  nixpak
  codingAgent.overlay
]
