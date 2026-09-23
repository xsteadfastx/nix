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
  home.packages = [ pkgs.unstable.ghostty ];

  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-style = Regular
    font-size = 14
    font-feature = zero
    shell-integration = fish
    theme = Dracula
    window-decoration = false
    gtk-single-instance = true
    mouse-hide-while-typing = true
    app-notifications = no-clipboard-copy
    bell-features = true
    desktop-notifications = true
  '';
}
