# Catppuccin flavour and accent, set once.
#
# Read by modules/catppuccin.nix (which feeds every program with a port) and by
# overlays/fluffychat-catppuccin.nix, whose theme cannot be switched at runtime
# and therefore has to be compiled per flavour.
{
  flavor = "mocha";
  accent = "mauve";
}
