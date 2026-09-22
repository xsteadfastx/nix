{
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;
in
lib.mkIf cfg.x11 {
  home.packages = with pkgs; [
    dracula-theme
    dracula-icon-theme
    jetbrainsmono-nerdfont-zero
  ];

  fonts.fontconfig.enable = true;

  gtk = {
    enable = true;

    theme = {
      name = "Dracula";
      package = pkgs.dracula-theme;
    };

    iconTheme = {
      name = "Dracula";
      package = pkgs.dracula-icon-theme;
    };

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 10;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    # NOTE: gtk4 deliberately has no `gtk-application-prefer-dark-theme` —
    # libadwaita rejects it; `colorScheme = "dark"` drives GTK4's dark mode.
    gtk4.extraConfig = { };
    gtk4.theme = {
      name = "Dracula";
      package = pkgs.dracula-theme;
    };
    colorScheme = "dark";
  };
  dconf.enable = true;

  home.pointerCursor = {
    package = pkgs.dracula-theme;
    name = "Dracula-Cursors";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # Qt apps mirror the GTK theme + font, and use the Dracula Kvantum style
  # (shipped by pkgs.dracula-theme) instead of adwaita-dark.
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "kvantum";
    kvantum.enable = true;
  };
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Dracula
  '';

  xdg.configFile."fontconfig/fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <alias>
        <family>sans-serif</family>
        <prefer>
          <family>JetBrainsMono Nerd Font</family>
        </prefer>
      </alias>
      <alias>
        <family>monospace</family>
        <prefer>
          <family>JetBrainsMono Nerd Font Mono</family>
        </prefer>
      </alias>
    </fontconfig>
  '';

  # GIMP 3 uses its own CSS theme engine with custom widget classes
  # (GimpDock, GimpToolPalette, etc.) that standard GTK themes don't target.
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
