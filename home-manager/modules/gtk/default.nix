{
  nixosConfig,
  lib,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  home.file.".gtkrc-2.0".text = ''
    gtk-theme-name = "Dracula"
    gtk-icon-theme-name = "Adwaita"
    gtk-font-name = "JetBrainsMono Nerd Font"
  '';

  xdg.configFile."gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=Dracula
    gtk-icon-theme-name=Adwaita
    gtk-font-name=JetBrainsMono Nerd Font, 10
  '';

  home.file.".themes/Dracula" = {
    source = ./Dracula;
    recursive = true;
  };

  xdg.configFile."assets" = {
    source = ./assets;
    recursive = true;
  };

  xdg.configFile."gtk-4.0" = {
    source = ./gtk-4.0;
    recursive = true;
  };

  # GIMP 3 uses its own CSS theme engine with custom widget classes
  # (GimpDock, GimpToolPalette, etc.) that standard GTK themes don't target.
  # This deploys a Dracula-specific gimp.css for those selectors.
  xdg.configFile."GIMP/3.0/themes/Dracula" = {
    source = ../gimp/Dracula;
    recursive = true;
  };
  xdg.configFile."GIMP/3.2/themes/Dracula" = {
    source = ../gimp/Dracula;
    recursive = true;
  };

  # Force GIMP's internal theme to Dracula on every rebuild. GIMP writes
  # gimprc on exit, so this is an activation script (not a managed file) to
  # avoid making gimprc read-only and breaking GIMP's own preference saving.
  home.activation.gimpDraculaTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for ver in 3.0 3.2; do
      rc="$HOME/.config/GIMP/$ver/gimprc"
      if [ -f "$rc" ]; then
        if grep -q '(theme ' "$rc"; then
          sed -i 's/(theme .*)/(theme "Dracula")/' "$rc"
        else
          echo '(theme "Dracula")' >> "$rc"
        fi
      fi
    done
  '';
}
