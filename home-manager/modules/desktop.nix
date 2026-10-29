{
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  imageMimeTypes = [
    "image/apng"
    "image/avif"
    "image/bmp"
    "image/gif"
    "image/heic"
    "image/jp2"
    "image/jpeg"
    "image/jxl"
    "image/png"
    "image/qoi"
    "image/svg+xml"
    "image/svg+xml-compressed"
    "image/tiff"
    "image/vnd.microsoft.icon"
    "image/webp"
    "image/x-dds"
    "image/x-exr"
    "image/x-portable-anymap"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-portable-pixmap"
    "image/x-qoi"
    "image/x-tga"
    "image/x-win-bitmap"
    "image/x-xbitmap"
    "image/x-xpixmap"
  ];
in
{
  imports = [
    # ./chromium.nix
    ./firefox.nix
    ./fonts
    ./ghostty.nix
    ./gtk
    ./niri
    ./applets.nix
    ./lock.nix
    ./swaync
    ./waybar
    ./fuzzel.nix
  ];

  # syncthingtray is a tray applet, so it belongs to the desktop, not to the
  # launcher/bar modules it used to be tacked onto.
  # Desktop tools that used to live in the sway module: the tray/manager applet,
  # the output-arrangement GUI and the screenshot chain (grim/slurp -> satty ->
  # wl-copy, native Wayland end to end).
  home.packages = lib.mkIf cfg.desktop (
    [
      pkgs.blueman
      pkgs.wdisplays
      pkgs.grim
      pkgs.slurp
      pkgs.satty
      pkgs.wl-clipboard
      pkgs.calibre
      pkgs.handbrake
      # pkgs.unstable.makemkv
      pkgs.unstable.evince
      pkgs.unstable.gimp
      pkgs.unstable.libmediainfo
      pkgs.unstable.loupe
      pkgs.unstable.mediaelch
      pkgs.unstable.mpv
      pkgs.unstable.mqttx
      pkgs.unstable.networkmanagerapplet
      pkgs.unstable.newsflash
      pkgs.unstable.pavucontrol
      pkgs.unstable.peek # gif screen recorder
      pkgs.unstable.rawtherapee
      pkgs.unstable.remmina
      pkgs.unstable.rustdesk-flutter
      pkgs.unstable.signal-desktop
      pkgs.unstable.system-config-printer
      pkgs.unstable.thunar
      pkgs.unstable.tor-browser
      pkgs.unstable.xdotool
      pkgs.unstable.xsaneGimp
    ]
    ++ lib.optional nixosConfig.services.syncthing.enable pkgs.unstable.syncthingtray
  );

  home.sessionVariables.DEFAULT_BROWSER = "firefox";

  # Detailed list instead of icons for every folder that has no view of its own.
  # Thunar reads the xfconf key "thunar"/"default-view" on each new window and
  # copies it into "last-view"; the GType name is the whole value. The key is
  # rewritten on every switch, so changing it in the GUI only lasts until the
  # next rebuild -- that is the point of setting it here.
  xfconf = lib.mkIf cfg.desktop {
    settings.thunar."default-view" = "ThunarDetailsView";
  };

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = lib.mkIf cfg.desktop (
    {
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
      "inode/directory" = [ "thunar.desktop" ];
    }
    // lib.genAttrs imageMimeTypes (_: [ "org.gnome.Loupe.desktop" ])
  );
}
