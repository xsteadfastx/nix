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
#   fluffychat-catppuccin.nix  a package built from pkgs.unstable, so it has to
#                          come after it
#   nixpak.nix             bubblewrap-sandboxed work apps
#   coding-agent.nix .overlay  surface coding-agent packages (their pinned nixpkgs) at top level
#
# Maintainer: Marvin Preuss <marv@yourdomain.com>
let
  packageOverrides = import ./package-overrides.nix { inherit inputs; };
  codingAgent = import ./coding-agent.nix { inherit inputs; };
  unstable = import ./unstable.nix { inherit inputs packageOverrides; };
  fluffychat = import ./fluffychat-catppuccin.nix { inherit inputs; };
  nixpak = import ./nixpak.nix { inherit inputs; };
in
inputs.nixpkgs.lib.composeManyExtensions [
  packageOverrides
  unstable
  fluffychat
  nixpak
  codingAgent.overlay
]
