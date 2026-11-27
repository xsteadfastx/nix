# Catppuccin flavour and accent, set once.
#
# Read by modules/catppuccin.nix (which feeds every program with a port) and by
# fluffychat-catppuccin (overlays/modifications.nix), whose theme cannot be
# switched at runtime and therefore has to be compiled per flavour.
{
  flavor = "mocha";
  accent = "mauve";
}
