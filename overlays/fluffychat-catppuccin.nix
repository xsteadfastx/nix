{
  inputs,
  ...
}:
# FluffyChat with the Catppuccin palette compiled in.
#
# Its own overlay rather than an entry in package-overrides.nix: the package is
# derived from `prev.unstable.fluffychat`, and package-overrides.nix is applied
# to the unstable instance as well, where that reference would recurse.
_final: prev:
let
  inherit (import ../lib/catppuccin.nix) flavor;
in
{
  fluffychat-catppuccin = prev.callPackage ../pkgs/fluffychat-catppuccin/package.nix {
    fluffychat = prev.unstable.fluffychat;

    # The palette repo, not a built port: evaluation-only, so a foreign host
    # needs no build just to generate the theme file.
    paletteFile = "${
      inputs.catppuccin.packages.${prev.stdenv.hostPlatform.system}.palette
    }/palette.json";

    inherit flavor;
  };
}
