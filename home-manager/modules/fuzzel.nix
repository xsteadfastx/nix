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
        font = "JetBrainsMono Nerd Font:size=16";
        # Same pixel size everywhere. With all outputs at scale 1, `auto` sizes
        # by the monitor's reported DPI, and the TV (1000x610 mm at 1360x768,
        # ~35 DPI) shrank the text to ~5 px.
        dpi-aware = "no";
        terminal = "${pkgs.unstable.ghostty}/bin/ghostty -e";
        list-executables-in-path = false;
        launch-prefix = "${pkgs.unstable.app2unit}/bin/app2unit --";

        # Room to breathe. Defaults are 30 chars / 15 lines / 40 px side padding
        # / 0 px between prompt and list; 15 lines is taller than the screen is
        # worth and 40 px of dead air reads odd in a flat, 1 px bordered window.
        # Icons are on by fuzzel's default already (icon-theme = "default"), and
        # they scale with the row height, so a bigger font scales them too.
        width = 40;
        lines = 10;
        horizontal-pad = 16;
        vertical-pad = 12;
        inner-pad = 8;
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
