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
      font-style = "Medium";
      font-size = 14;
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
