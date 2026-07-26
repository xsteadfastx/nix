{
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
{
  imports = [
    ./chromium.nix
    ./fonts
    ./ghostty.nix
    ./gtk
    ./i3
  ];

  home.packages = lib.mkIf cfg.x11 [
    pkgs.calibre
    pkgs.handbrake
    pkgs.makemkv
    pkgs.unstable.arandr
    pkgs.unstable.evince
    pkgs.unstable.gimp
    pkgs.unstable.libmediainfo
    pkgs.unstable.mediaelch
    pkgs.unstable.mpv
    pkgs.unstable.mqttx
    pkgs.unstable.networkmanagerapplet
    pkgs.unstable.pavucontrol
    pkgs.unstable.pcmanfm
    pkgs.unstable.peek # gif screen recorder
    pkgs.unstable.rawtherapee
    pkgs.unstable.remmina
    pkgs.unstable.rustdesk-flutter
    pkgs.unstable.signal-desktop
    pkgs.unstable.slack
    pkgs.unstable.system-config-printer
    pkgs.unstable.tor-browser
    pkgs.unstable.xdotool
    pkgs.unstable.xsaneGimp

    (lib.mkIf cfg.work pkgs._1password-cli)
    (lib.mkIf cfg.work pkgs._1password-gui)
  ];

  home.sessionVariables.DEFAULT_BROWSER = "chromium";

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = lib.mkIf cfg.x11 {
    "x-scheme-handler/http" = [ "chromium-browser.desktop" ];
    "x-scheme-handler/https" = [ "chromium-browser.desktop" ];
    "x-scheme-handler/ftp" = [ "chromium-browser.desktop" ];
  };
}
