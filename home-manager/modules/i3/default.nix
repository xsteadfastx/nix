{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  xdg.configFile."i3/config".source = ./config;

  home.packages = [
    (pkgs.writeShellScriptBin "i3auto" ''
      set -e
      ${pkgs.xorg.xsetroot}/bin/xsetroot -solid "#282a36"
      ${pkgs.dunst}/bin/dunst &
      ${pkgs.networkmanagerapplet}/bin/nm-applet &
      setxkbmap -option "caps:super"
      ${pkgs.blueman}/bin/blueman-applet &
      ${pkgs.autorandr}/bin/autorandr -c
      xset s 60 60
      ${pkgs.flameshot}/bin/flameshot &
    '')
  ];
}
