{
  nixosConfig,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
{
  imports = [
    ./fonts
    ./ghostty.nix
    ./gtk
    ./i3
  ];

  home.packages =
    with pkgsUnstable;
    lib.mkIf cfg.x11 [
      # beekeeper-studio # sql
      # quickemu
      arandr
      bumblebee-status
      evince
      gimp
      handbrake
      libmediainfo
      makemkv
      mediaelch
      mpv
      mqttx
      networkmanagerapplet
      pavucontrol
      pcmanfm
      peek # gif screen recorder
      pkgs.calibre
      rawtherapee
      remmina
      rustdesk
      signal-desktop
      slack
      system-config-printer
      tor-browser
      xdotool
      xsaneGimp
      meshcore-cli
      meshcore-web

      (lib.mkIf cfg.work _1password-cli)
      (lib.mkIf cfg.work _1password-gui)
    ];

  home.sessionVariables.DEFAULT_BROWSER = "chromium";

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = lib.mkIf cfg.x11 {
    "x-scheme-handler/http" = [ "chromium-browser.desktop" ];
    "x-scheme-handler/https" = [ "chromium-browser.desktop" ];
    "x-scheme-handler/ftp" = [ "chromium-browser.desktop" ];
  };
}
