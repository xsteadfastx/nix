{
  lib,
  nixosConfig,
  pkgsUnstable,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  home.packages = [ pkgsUnstable.ghostty ];

  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-style = Regular
    font-size = 13
    shell-integration = fish
    theme = Dracula
    window-decoration = false
    gtk-single-instance = true
    mouse-hide-while-typing = true
    app-notifications = no-clipboard-copy
  '';
}
