{
  inputs,
  ...
}:
inputs.nixpkgs.lib.composeManyExtensions [
  (import ./additions.nix) # our packages from pkgs/
  (import ./modifications.nix { inherit inputs; }) # overrides, wrappers, flake-input packages
  (import ./unstable.nix { inherit inputs; }) # pkgs.unstable
  (import ./nixpak.nix { inherit inputs; })
  (import ./coding-agent.nix { inherit inputs; }).overlay
]
