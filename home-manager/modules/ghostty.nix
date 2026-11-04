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
      font-family = "Lilex Nerd Font";
      # 15pt = 20px here. At 14pt (18.67px) no hinting variant sharpened
      # Lilex without distorting its widths; the larger size was the only
      # clear gain on the ~92 DPI externals (ghostty is grayscale-only).
      font-size = 15;
      # Explicit as well: the fontconfig Lilex Regular -> Medium rule
      # (home-manager/modules/gtk) cannot catch a request by style name.
      font-style = "Medium";
      # Lilex draws `->`, `=>` & co. from two glyphs, which FreeType hints
      # separately: at 15pt the shaft snapped a pixel below the arrowhead
      # (mishamyrt/Lilex#50, size-dependent, wontfix upstream). Unhinted, both
      # stay on the same row at every size, at the cost of slightly softer
      # edges. Measured in ghostty 1.4: hinted 11.45 vs 10.58, unhinted 11.43
      # vs 11.38 (row of shaft vs head).
      freetype-load-flags = "no-hinting";
      shell-integration = "fish";
      window-decoration = false;
      gtk-single-instance = true;
      mouse-hide-while-typing = true;
      app-notifications = "no-clipboard-copy";
      bell-features = "true";
      desktop-notifications = true;
    };
  };
}
