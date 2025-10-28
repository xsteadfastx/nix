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
}
