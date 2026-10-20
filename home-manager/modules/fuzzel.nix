{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  # Colours from the table the bar, swaync and the lock screen render from
  # (../lib/statusbar.nix), as fuzzel's RRGGBBAA. The picks are the official
  # Dracula fuzzel theme (github.com/dracula/fuzzel): dd = slightly translucent.
  inherit ((import ../lib/statusbar.nix { inherit lib; })) palette;
  rgba = name: alpha: lib.removePrefix "#" palette.${name} + alpha;
in
lib.mkIf cfg.desktop {
  # The launcher and dmenu (replaced wofi). Mod+D, the gopass picker and the
  # window switcher in ../niri call it by store path, so keep this package attr
  # and those identical.
  programs.fuzzel = {
    enable = true;
    package = pkgs.unstable.fuzzel;

    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=11";
        terminal = "${pkgs.unstable.ghostty}/bin/ghostty -e";
        list-executables-in-path = false;
        launch-prefix = "${pkgs.unstable.app2unit}/bin/app2unit --";
      };

      colors = {
        background = rgba "background" "dd";
        text = rgba "foreground" "ff";
        match = rgba "cyan" "ff";
        selection-match = rgba "cyan" "ff";
        selection = rgba "selection" "dd";
        selection-text = rgba "foreground" "ff";
        border = rgba "purple" "ff";
      };

      # Square 1px border, like the window borders and the bar.
      border = {
        width = 1;
        radius = 0;
      };
    };
  };
}
