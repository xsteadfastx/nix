{
  pkgs,
  lib,
  nixosConfig,
  ...
}:
let
  cfg = nixosConfig.features;
in
lib.mkIf cfg.desktop {
  # `programs.ghostty.settings` instead of a hand-written config file: the theme
  # is then owned by catppuccin.ghostty (home-manager/modules/catppuccin.nix), which installs
  # the theme file and sets `theme = "light:<f>,dark:<f>"` -- no flavour string
  # here, and no second writer for ~/.config/ghostty/config.
  #
  # The package is pinned here rather than added to home.packages: the module
  # installs its own `package`, and two ghostty builds in the profile collide on
  # share/bat/syntaxes/ghostty.sublime-syntax.
  programs.ghostty = {
    enable = true;
    package = pkgs.unstable.ghostty;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      # 15pt = 20px here, a whole-pixel em on the ~92 DPI externals (ghostty is
      # grayscale-only).
      font-size = 15;
      # Medium, not Regular: sharper at 92 DPI (see the fontconfig rule in
      # gtk/default.nix). Set by name because a style request slips past that
      # weight rule.
      font-style = "Medium";
      # No freetype-load-flags: ghostty's defaults (hinting, light target) are
      # what we want, and they measured sharper than the unhinted rendering
      # (0.379 vs 0.359 fully-snapped ink pixels at 20px). The `no-hinting` this
      # used to set was a Lilex workaround: Lilex builds `->`/`=>` from two
      # glyphs that FreeType hints separately and misaligns at some sizes
      # (mishamyrt/Lilex#50). JetBrains Mono draws them as one glyph (its
      # ligatures come from `calt`, which ghostty enables), so hinting is safe
      # here.
      shell-integration = "fish";
      # ghostty 1.4 reworked copy-on-select (ghostty#12600): the Linux default
      # `primary` fills only the PRIMARY selection, so selecting text no longer
      # lands on the CLIPBOARD that Ctrl+Shift+V pastes from. `both` restores
      # the 1.3 behavior: mark + select copies to PRIMARY *and* CLIPBOARD.
      copy-on-select = "both";
      window-decoration = false;
      gtk-single-instance = true;
      mouse-hide-while-typing = true;
      app-notifications = "no-clipboard-copy";
      bell-features = "true";
      desktop-notifications = true;
    };
  };
}
