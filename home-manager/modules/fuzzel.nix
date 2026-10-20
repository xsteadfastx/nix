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
        # wofi's `drun,run`: apps plus every executable on $PATH.
        list-executables-in-path = true;
        # Each app gets its own systemd scope (app-niri-<entry-id>-<rand>.scope)
        # instead of running inside the launcher's. The XDG portal derives a
        # host app's id from that scope name: under plain spawning every app
        # started from the launcher was "wofi" to it (Meshy's autostart file
        # was written as wofi.desktop). fuzzel >= 1.14 passes the desktop entry
        # to app2unit through DESKTOP_ENTRY_* itself.
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
