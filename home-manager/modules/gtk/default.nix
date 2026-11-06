{
  config,
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  inherit (config.catppuccin) flavor accent;
  ctp = import ../../../lib/palette.nix {
    inherit lib;
    inherit (config) catppuccin;
  };

  # Catppuccin's Kvantum style is built for Plasma: `popup_blurring=true` and
  # `reduce_window_opacity=10` assume a compositor that blurs what is behind a
  # dialog. niri has no blur, so dialogs showed the window behind them
  # (MediaElch settings, 2026-10-22). Main windows are already solid upstream
  # (`translucent_windows=false`), so only those two keys need turning off.
  kvantumName = "catppuccin-${flavor}-${accent}";
  kvantumSolid = pkgs.runCommand "kvantum-${kvantumName}-solid" { } ''
    src=${config.catppuccin.sources.kvantum}/share/Kvantum/${kvantumName}
    dst=$out/share/Kvantum/${kvantumName}-solid
    mkdir -p $dst
    cp $src/${kvantumName}.svg $dst/${kvantumName}-solid.svg
    sed \
      -e 's/^popup_blurring=.*/popup_blurring=false/' \
      -e 's/^reduce_window_opacity=.*/reduce_window_opacity=0/' \
      $src/${kvantumName}.kvconfig > $dst/${kvantumName}-solid.kvconfig
    # an upstream key rename would make a substitution miss silently
    for want in popup_blurring=false reduce_window_opacity=0; do
      grep -qx "$want" $dst/${kvantumName}-solid.kvconfig || { echo "missing: $want"; exit 1; }
    done
  '';

  # GIMP 3 has no Catppuccin port and reads no palette file, so its
  # @define-color block is generated from lib/palette.nix and prepended to the
  # layout CSS beside this module (which keeps no colours of its own).
  #
  # Widget surfaces use surface0, not surface1: surface1 is #45475a, which is
  # 2/255 from Dracula's #44475a, so a GIMP whose buttons, borders and text
  # areas all sat on surface1 still read as the old Dracula theme. Hover and
  # selection keep surface1 -- one shade only under a pointer/selection is a
  # hover cue, not the dominant surface.
  gimpColors = {
    "fg-color" = "text";
    "bg-color" = "base";
    "bg-dark-color" = "crust";
    "border-color" = "surface0";
    "bg-extra-dark-color" = "crust";
    "light-special-color" = "mauve";
    "dimmed-fg-color" = "subtext0";
    "disabled-fg-color" = "overlay0";
    "disabled-button-color" = "surface0";
    "hover-color" = "surface1";
    "bright-border-color" = "mauve";
    sap = "crust";
    border = "surface0";
    canvas = "base";
    slider = "mauve";
    "fg2-color" = "text";
    "widget-bg-color" = "surface0";
    "selected-color" = "surface1";
    "extreme-bg-color" = "surface0";
    "extreme-selected-color" = "crust";
    "strong-border-color" = "crust";
    "stronger-border-color" = "overlay0";
    "edge-border-color" = "crust";
    "scrollbar-slider-color" = "mauve";
    "scrollbar-trough-color" = "crust";
    "ruler-color" = "crust";
  };
  gimpCss =
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: color: "@define-color ${name} ${ctp.hex color};") gimpColors
    )
    + "\n\n"
    + builtins.readFile ../gimp/Catppuccin/gimp.css;

  # One build of each theme, used by gtk.theme and gtk4.theme alike.
  gtkTheme = pkgs.catppuccin-gtk.override {
    variant = flavor;
    accents = [ accent ];
  };
in
lib.mkIf cfg.desktop {
  home = {
    # Name/package come from catppuccin.cursors (home-manager/modules/catppuccin.nix); only
    # the GTK/X11 propagation is ours -- its module does not set `gtk.enable`,
    # so without this the cursor name never lands in gtk-3.0/settings.ini.
    pointerCursor = {
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    # The Papirus icon theme comes from catppuccin.gtk.icon.
    packages = with pkgs; [
      gtkTheme
      lilex-nerdfont-zero
    ];

    # GIMP 3 uses its own CSS theme engine with custom widget classes
    # (GimpDock, GimpToolPalette, etc.) that standard GTK themes don't target.
    # Force GIMP's internal theme to Catppuccin on every rebuild. GIMP writes
    # gimprc on exit, so this is an activation script (not a managed file) to
    # avoid making gimprc read-only and breaking GIMP's own preference saving.
    activation.gimpCatppuccinTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for ver in 3.0 3.2; do
        rc="$HOME/.config/GIMP/$ver/gimprc"
        if [ -f "$rc" ]; then
          if grep -q '(theme ' "$rc"; then
            sed -i 's/(theme .*)/(theme "Catppuccin")/' "$rc"
          else
            echo '(theme "Catppuccin")' >> "$rc"
          fi
        fi
      done
    '';

  };

  fonts.fontconfig.enable = true;

  gtk = {
    enable = true;

    theme = {
      name = "catppuccin-${flavor}-${accent}-standard";
      package = gtkTheme;
    };

    # 11pt: 10pt Lilex reads soft on the ~92 DPI externals. The weight is
    # Medium through the fontconfig rule below, not through this name
    # (libadwaita's CSS would override a weight given here).
    font = {
      name = "Lilex Nerd Font";
      size = 11;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    # NOTE: `gtk-application-prefer-dark-theme` is not set here, but Home
    # Manager's own mkGtkSettings writes it into gtk-4.0/settings.init for
    # colorScheme = "dark" anyway, which is why every libadwaita app logs
    # "Using GtkSettings:gtk-application-prefer-dark-theme with libadwaita is
    # unsupported". Harmless: libadwaita ignores it and follows the dconf
    # color-scheme instead.
    # GTK >= 4.16 defaults to "automatic" rendering: subpixel positioning with
    # unhinted metrics, which reads blurry at scale 1 on the ~92 DPI
    # externals. `manual` + hinted metrics puts glyphs back on whole pixels.
    # The GNOME settings portal feeds GTK 4 from dconf and overrides this
    # file, so font-rendering is also set in dconf below; hint-font-metrics
    # has no dconf key and only works from here.
    gtk4.extraConfig = {
      gtk-font-rendering = "manual";
      gtk-hint-font-metrics = 1;
    };
    gtk4.theme = {
      name = "catppuccin-${flavor}-${accent}-standard";
      package = gtkTheme;
    };
    # libadwaita paints sidebar widgets from its own colour set. The Catppuccin
    # GTK4 port only defines theme_bg_color, so @sidebar_bg_color and
    # @sidebar_fg_color resolve to nothing there and the sidebar falls back to
    # light defaults -- NewsFlash's unread badge (`.item-count`, i.e.
    # `mix(@sidebar_fg_color, white, 0.4)` behind `color: @sidebar_bg_color`)
    # came out white text on a white pill. HM appends this after the @import,
    # so it wins over the theme.
    gtk4.extraCss = ''
      @define-color sidebar_bg_color ${ctp.hex "base"};
      @define-color sidebar_fg_color ${ctp.hex "text"};

      /* The @define-colors above do not reach an app rule that was parsed
         before them, so NewsFlash's unread badge stays white-on-white:
         `.custom-sidebar .item-count` mixes @sidebar_fg_color with white and
         paints the number in @sidebar_bg_color. Overriding the rule itself at
         user priority is the only reliable way in. */
      .custom-sidebar .item-count {
        background-color: ${ctp.hex "text"};
        color: ${ctp.hex "base"};
      }
      /* NewsFlash adds its own provider to the display as well, so the plain
         selector ties with it. The doubled class wins on specificity whatever
         order the providers landed in. */
      .custom-sidebar .item-count.item-count {
        background-color: ${ctp.hex "text"};
        color: ${ctp.hex "base"};
      }
    '';
    colorScheme = "dark";
  };
  dconf.enable = true;
  # Read by GTK 4 through the settings portal (see gtk4.extraConfig above).
  dconf.settings."org/gnome/desktop/interface".font-rendering = "manual";

  # Qt apps mirror the GTK theme + font, and use the Catppuccin Kvantum style
  # (solid, see kvantumSolid above) instead of adwaita-dark. The kvconfig is
  # generated by qt.kvantum from these settings — writing
  # xdg.configFile."Kvantum/kvantum.kvconfig" by hand loses: the module owns that
  # path (it generates "kvantum-config"), so a hand-written theme= value is
  # silently replaced by the default theme=null and Qt stays unthemed.
  qt = {
    enable = true;
    # gtk3, not gtk: the GTK3 platform theme plugin (libqgtk3.so) ships inside
    # qtbase for both Qt 5 and 6, so it needs no extra package and no GTK2 --
    # whereas "gtk" maps to QT_QPA_PLATFORMTHEME=gtk2, which pulled
    # qtstyleplugins/qt6gtk2 and gtk+ 2.24.33 (removed from nixpkgs in 27.05).
    platformTheme.name = "gtk3";
    style.name = "kvantum";
    kvantum = {
      enable = true;
      themes = [ kvantumSolid ];
      settings.General.theme = "${kvantumName}-solid";
    };
  };

  xdg = {
    configFile = {
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
              <family>Lilex Nerd Font</family>
            </prefer>
          </alias>
          <alias binding="same">
            <family>monospace</family>
            <prefer>
              <family>Lilex Nerd Font Mono</family>
            </prefer>
          </alias>
          <!-- niri's own UI (hotkey overlay, screenshot UI) asks fontconfig for
               the generic families above *and* for `mono`; unaliased, that one
               resolves to DejaVu Sans Mono. -->
          <alias binding="same">
            <family>mono</family>
            <prefer>
              <family>Lilex Nerd Font Mono</family>
            </prefer>
          </alias>
          <!-- Lilex Regular reads thin and soft on the ~92 DPI externals, so a
               request for Lilex at the regular weight gets Medium instead,
               whatever asked for it: GTK, libadwaita CSS (which pins
               font-weight: 400 and so ignores a "Medium" in gtk-font-name),
               waybar, fuzzel, swaync, ghostty. Bold, italic and lighter
               weights are untouched. A config that says "Regular" for Lilex
               therefore renders Medium; this rule is why. -->
          <match target="pattern">
            <test name="family" compare="contains"><string>Lilex</string></test>
            <!-- qual="all" also matches a request without any weight
                 (fuzzel, plain fc-match), which a plain eq test misses -->
            <test qual="all" name="weight" compare="more_eq"><const>regular</const></test>
            <test qual="all" name="weight" compare="less"><const>medium</const></test>
            <edit name="weight" mode="assign" binding="strong"><const>medium</const></edit>
          </match>
        </fontconfig>
      '';

      # GIMP 3 uses its own CSS theme engine with custom widget classes
      # (GimpDock, GimpToolPalette, etc.) that standard GTK themes don't target.
      "GIMP/3.0/themes/Catppuccin/gimp.css".text = gimpCss;
      "GIMP/3.2/themes/Catppuccin/gimp.css".text = gimpCss;
    };
  };
}
