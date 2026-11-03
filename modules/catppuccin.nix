{ inputs, ... }:
# Catppuccin flavour and accent, set once. Imported by modules/home-manager and
# switched on there with `features.desktop`; Home Manager follows these
# (home-manager/modules/catppuccin.nix), and modules/base themes trippy when
# it is on.
#
# `enable` themes every NixOS-level port whose program is on -- on coltrane
# that is only the tty console (grub, plymouth, sddm, … are off there).
{
  imports = [ inputs.catppuccin.nixosModules.catppuccin ];

  catppuccin = {
    flavor = "mocha";
    accent = "mauve";
  };
}
