# The configured Catppuccin flavour's colours, read from catppuccin/nix's own
# palette source (`catppuccin.sources.palette`). Only for programs without a
# Catppuccin port; everything else is themed by its catppuccin.* module.
#
# Read from `.src` (the fetched repo), not the built port: the fetch is a
# fixed-output path shared by every platform, so an aarch64 host (phil) does
# not need an aarch64 build just to evaluate.
#
#   ctp = import ../lib/palette.nix { inherit lib; inherit (config) catppuccin; };
#   ctp.hex "mauve"  # "#cba6f7"
{ lib, catppuccin }:
let
  colors =
    (lib.importJSON "${catppuccin.sources.palette.src}/palette.json").${catppuccin.flavor}.colors;
  rgb =
    name: with colors.${name}.rgb; [
      r
      g
      b
    ];
in
{
  inherit colors rgb;

  hex = name: colors.${name}.hex;

  # `mix "red" "base" 0.8`: 80% of the way from red towards base, as hex. For
  # the one shade the palette has no name for (zellij's ssh pane tint).
  mix =
    from: towards: t:
    "#"
    + lib.concatStrings (
      lib.zipListsWith (
        x: y:
        lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString (builtins.floor (x + (y - x) * t + 0.5))))
      ) (rgb from) (rgb towards)
    );
}
