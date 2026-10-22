{
  config,
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  inherit ((import ../../lib/statusbar.nix { inherit lib; })) palette;

  # Dracula's Kvantum theme makes every window 18% translucent and leaves the
  # see-through to KWin's blur. niri has no blur, so dialogs showed the window
  # behind them (MediaElch settings, 2026-10-22). Same theme, solid, plus link
  # colours that read on #282a36 (upstream: #646464 / #7f8c8d).
  draculaSolidKvantum = pkgs.runCommand "kvantum-dracula-solid" { } ''
    src=${pkgs.dracula-theme}/share/Kvantum/Dracula
    dst=$out/share/Kvantum/DraculaSolid
    mkdir -p $dst
    cp $src/Dracula.svg $dst/DraculaSolid.svg
    sed \
      -e 's/^translucent_windows=.*/translucent_windows=false/' \
      -e 's/^blurring=.*/blurring=false/' \
      -e 's/^popup_blurring=.*/popup_blurring=false/' \
      -e 's/^reduce_window_opacity=.*/reduce_window_opacity=0/' \
      -e 's/^link.color=.*/link.color=${palette.cyan}/' \
      -e 's/^link.visited.color=.*/link.visited.color=${palette.purple}/' \
      $src/Dracula.kvconfig > $dst/DraculaSolid.kvconfig
    # an upstream key rename would make a substitution miss silently
    for want in translucent_windows=false blurring=false popup_blurring=false \
      reduce_window_opacity=0 'link.color=${palette.cyan}' 'link.visited.color=${palette.purple}'; do
      grep -qx "$want" $dst/DraculaSolid.kvconfig || { echo "missing: $want"; exit 1; }
    done
  '';

  # Palette for Qt Quick apps, which can't use Kvantum (nheko, see ../matrix.nix):
  # they get QT_QPA_PLATFORMTHEME=qt6ct and read it from here. It is the Kvantum
  # palette above with the roles gtk2 leaves unset filled in -- links at Qt's
  # #0000ff, and light/dark, which nheko reads as button text and background
  # (FlatButton.qml), dark-on-dark. Not dracula/qt5's Dracula.conf: that one
  # sets text to comment (dim) and the placeholder to selection (invisible).
  qt6ctPalette =
    let
      # Not in the Dracula spec: the Dracula Kvantum theme's own window and
      # highlight colours and gtk2's alternate base, kept so a qt6ct app and a
      # Kvantum app look the same next to each other.
      kvantum = {
        window = "#1e1f29";
        highlight = "#7c60a3";
        alternateBase = "#242630";
      };
      # qt6ct writes one comma list per colour group, in QPalette's role order.
      roles = [
        "WindowText"
        "Button"
        "Light"
        "Midlight"
        "Dark"
        "Mid"
        "Text"
        "BrightText"
        "ButtonText"
        "Base"
        "Window"
        "Shadow"
        "Highlight"
        "HighlightedText"
        "Link"
        "LinkVisited"
        "AlternateBase"
        "NoRole"
        "ToolTipBase"
        "ToolTipText"
        "PlaceholderText"
      ];
      group =
        colors: lib.concatMapStringsSep ", " (role: "#ff${lib.removePrefix "#" colors.${role}}") roles;
      active = with palette; {
        WindowText = foreground;
        Button = kvantum.window;
        Light = foreground;
        Midlight = selection;
        Dark = selection;
        Mid = selection;
        Text = foreground;
        BrightText = "#ffffff";
        ButtonText = foreground;
        Base = background;
        Window = kvantum.window;
        Shadow = "#000000";
        Highlight = kvantum.highlight;
        HighlightedText = foreground;
        Link = cyan;
        LinkVisited = purple;
        AlternateBase = kvantum.alternateBase;
        NoRole = "#000000";
        ToolTipBase = kvantum.window;
        ToolTipText = foreground;
        PlaceholderText = comment;
      };
      disabled =
        active
        // (with palette; {
          WindowText = comment;
          Light = comment;
          Dark = background;
          Text = comment;
          ButtonText = comment;
          Highlight = selection;
          HighlightedText = comment;
          Link = comment;
          LinkVisited = comment;
        });
    in
    pkgs.writeText "dracula-qt6ct.conf" ''
      [ColorScheme]
      active_colors=${group active}
      inactive_colors=${group active}
      disabled_colors=${group disabled}
    '';
in
lib.mkIf cfg.desktop {
  home = {
    packages = with pkgs; [
      dracula-theme
      dracula-icon-theme
      jetbrainsmono-nerdfont-zero
      # Ships the GTK2 engines, incl. the Adwaita one. qt.platformTheme "gtk"
      # maps to QT_QPA_PLATFORMTHEME=gtk2, so Qt reads the theme through GTK2 and
      # without this it warns "Unable to locate theme engine in module_path:
      # adwaita" and falls back to its built-in palette instead of Dracula.
      gnome-themes-extra
    ];
    pointerCursor = {
      package = pkgs.dracula-theme;
      # The package ships the theme dir as "Dracula-cursors" (lowercase c) --
      # this used to say "Dracula-Cursors", a name that doesn't exist on a
      # case-sensitive filesystem, so the whole cursor theme silently failed to
      # load (not just the specific glyphs GTK warned about, e.g. "Unable to
      # load hand2/arrow from the cursor theme" -- confirmed live: the
      # generated symlink chain resolved to a nonexistent path).
      name = "Dracula-cursors";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    # GIMP 3 uses its own CSS theme engine with custom widget classes
    # (GimpDock, GimpToolPalette, etc.) that standard GTK themes don't target.
    # Force GIMP's internal theme to Dracula on every rebuild. GIMP writes
    # gimprc on exit, so this is an activation script (not a managed file) to
    # avoid making gimprc read-only and breaking GIMP's own preference saving.
    activation.gimpDraculaTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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

    # Same for nheko: only its "System" theme uses the qt6ct palette, Light and
    # Dark are hard-coded (src/ui/Theme.cpp), and it rewrites nheko.conf itself.
    activation.nhekoSystemTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      rc="$HOME/.config/nheko/nheko.conf"
      if [ -f "$rc" ]; then
        if grep -q '^theme=' "$rc"; then
          sed -i 's/^theme=.*/theme=system/' "$rc"
        elif grep -q '^\[user\]' "$rc"; then
          sed -i '/^\[user\]/a theme=system' "$rc"
        fi
      fi
    '';
  };

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

  # Qt apps mirror the GTK theme + font, and use the Dracula Kvantum style
  # (shipped by pkgs.dracula-theme) instead of adwaita-dark. The kvconfig is
  # generated by qt.kvantum from these settings — writing
  # xdg.configFile."Kvantum/kvantum.kvconfig" by hand loses: the module owns that
  # path (it generates "kvantum-config"), so the hand-written theme=Dracula was
  # silently replaced by the default theme=null and Qt stayed unthemed.
  # Qt Quick apps can't use Kvantum; they use qt6ctPalette above.
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "kvantum";
    kvantum = {
      enable = true;
      themes = [ draculaSolidKvantum ];
      settings.General.theme = "DraculaSolid";
    };
  };

  xdg = {
    configFile = {
      # Only read by apps started with QT_QPA_PLATFORMTHEME=qt6ct (nheko). Font
      # and icons are the GTK ones the gtk2 platform theme hands every other Qt
      # app; file dialogs go through the portal instead of gtk2.
      "qt6ct/qt6ct.conf".text = ''
        [Appearance]
        custom_palette=true
        color_scheme_path=${qt6ctPalette}
        icon_theme=${config.gtk.iconTheme.name}
        standard_dialogs=xdgdesktopportal

        [Fonts]
        general="${config.gtk.font.name},${toString config.gtk.font.size}"
        fixed="JetBrainsMono Nerd Font Mono,${toString config.gtk.font.size}"
      '';
      "fontconfig/fonts.conf".text = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <!-- binding="same" is required: with the default (weak) binding,
               fontconfig ignores these aliases for the generic family
               completely and hands back DejaVu anyway. Verified with fc-match
               against this file. -->
          <alias binding="same">
            <family>sans-serif</family>
            <prefer>
              <family>JetBrainsMono Nerd Font</family>
            </prefer>
          </alias>
          <alias binding="same">
            <family>monospace</family>
            <prefer>
              <family>JetBrainsMono Nerd Font Mono</family>
            </prefer>
          </alias>
          <!-- niri's own UI (hotkey overlay, screenshot UI) asks fontconfig for
               the generic families above *and* for `mono`; unaliased, that one
               resolves to DejaVu Sans Mono. -->
          <alias binding="same">
            <family>mono</family>
            <prefer>
              <family>JetBrainsMono Nerd Font Mono</family>
            </prefer>
          </alias>
        </fontconfig>
      '';

      # GIMP 3 uses its own CSS theme engine with custom widget classes
      # (GimpDock, GimpToolPalette, etc.) that standard GTK themes don't target.
      "GIMP/3.0/themes/Dracula" = {
        source = ../gimp/Dracula;
        recursive = true;
      };
      "GIMP/3.2/themes/Dracula" = {
        source = ../gimp/Dracula;
        recursive = true;
      };
    };
  };
}
