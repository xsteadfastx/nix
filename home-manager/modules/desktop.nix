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
  # Calibre claims the OOXML document types on install; these win over it.
  # Each type must name the component that actually declares it in its MimeType
  # line -- startcenter declares none of them, so pointing the defaults there
  # (or at a name that does not exist) silently falls back to Calibre again.
  officeApplication = {
    "application/msword" = "writer";
    "application/rtf" = "writer";
    "application/vnd.oasis.opendocument.text" = "writer";
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "writer";
    "application/vnd.ms-excel" = "calc";
    "application/vnd.oasis.opendocument.spreadsheet" = "calc";
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "calc";
    "application/vnd.ms-powerpoint" = "impress";
    "application/vnd.oasis.opendocument.presentation" = "impress";
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = "impress";
  };
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
      pkgs.libreoffice
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
      pkgs.unstable.simple-scan
      pkgs.unstable.system-config-printer
      pkgs.unstable.thunar
      pkgs.unstable.tor-browser
      pkgs.unstable.xdotool
    ]
    ++ lib.optional nixosConfig.services.syncthing.enable pkgs.unstable.syncthingtray
  );

  # calibre keeps the list of installed plugins in its own config
  # (config['plugins'], name -> zip path) and only then loads the zip from
  # ~/.config/calibre/plugins/. Merely dropping the zip there is not enough, and
  # that config file is rewritten by calibre itself, so managing it as a
  # home.file would fight the app. `calibre-customize -a` is the supported
  # registration path: it is idempotent (removes and re-copies), so re-running it
  # on every activation both installs and upgrades the plugins.
  home.activation.calibre-plugins = lib.mkIf cfg.desktop (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${lib.escapeShellArgs [
        "${pkgs.calibre}/bin/calibre-customize"
        "-a"
        "${pkgs.calibre-dedrm-plugin}/DeDRM_plugin.zip"
      ]}
      ${lib.escapeShellArgs [
        "${pkgs.calibre}/bin/calibre-customize"
        "-a"
        "${pkgs.calibre-dedrm-plugin}/Obok_plugin.zip"
      ]}
    ''
  );

  home.sessionVariables = {
    DEFAULT_BROWSER = "firefox";
    # On Linux calibre ignores QT_STYLE_OVERRIDE and forces its own Fusion-based
    # style + palette unless this is set; with it, calibre follows Kvantum.
    CALIBRE_USE_SYSTEM_THEME = lib.mkIf cfg.desktop "1";
  };

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
      # Calibre claims this on install; PDFs are documents first, ebooks second.
      "application/pdf" = [ "org.gnome.Evince.desktop" ];
    }
    // lib.genAttrs imageMimeTypes (_: [ "org.gnome.Loupe.desktop" ])
    // lib.mapAttrs (_: app: [ "${app}.desktop" ]) officeApplication
  );
}
