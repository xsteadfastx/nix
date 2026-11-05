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
  home.packages = lib.mkIf cfg.desktop [ pkgs.calibre ];

  # calibre keeps the list of installed plugins in its own config
  # (config['plugins'], name -> zip path) and only then loads the zip from
  # ~/.config/calibre/plugins/. Merely dropping the zip there is not enough, and
  # that config file is rewritten by calibre itself, so managing it as a
  # home.file would fight the app. `calibre-customize -a` is the supported
  # registration path: it is idempotent (removes and re-copies), so re-running it
  # on every activation both installs and upgrades the plugins.
  #
  # DeDRM + Obok come from the maintained fork (Satsuoni), which also needs no
  # separate key import: it picks up DeACSM's Adobe key on its own. DeACSM exists
  # to fulfill Adobe-DRM .acsm files (Thalia, Kobo, Onleihe, Google Play) into
  # EPUB/PDF first.
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
      ${lib.escapeShellArgs [
        "${pkgs.calibre}/bin/calibre-customize"
        "-a"
        "${pkgs.calibre-deacsm-plugin}/DeACSM_plugin.zip"
      ]}
    ''
  );

  home.sessionVariables = lib.mkIf cfg.desktop {
    # On Linux calibre ignores QT_STYLE_OVERRIDE and forces its own Fusion-based
    # style + palette unless this is set; with it, calibre follows Kvantum.
    CALIBRE_USE_SYSTEM_THEME = "1";
  };
}
