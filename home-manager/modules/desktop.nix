{
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;
in
{
  imports = [
    ./chromium.nix
    ./fonts
    ./ghostty.nix
    ./gtk
    ./sway
    ./swaync
    ./waybar
    ./wofi.nix
  ];

  # syncthingtray is a tray applet, so it belongs to the desktop, not to the
  # wofi/bar modules it used to be tacked onto.
  home.packages = lib.mkIf cfg.desktop (
    [
      pkgs.calibre
      pkgs.handbrake
      # pkgs.unstable.makemkv
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
      pkgs.unstable.system-config-printer
      pkgs.unstable.tor-browser
      pkgs.unstable.xdotool
      pkgs.unstable.xsaneGimp
    ]
    ++ lib.optional nixosConfig.services.syncthing.enable pkgs.unstable.syncthingtray
  );

  home.sessionVariables.DEFAULT_BROWSER = "chromium";

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = lib.mkIf cfg.desktop {
    "x-scheme-handler/http" = [ "chromium-browser.desktop" ];
    "x-scheme-handler/https" = [ "chromium-browser.desktop" ];
    "x-scheme-handler/ftp" = [ "chromium-browser.desktop" ];
  };
}
