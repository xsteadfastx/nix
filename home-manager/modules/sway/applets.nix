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
  # nm-applet and syncthingtray as systemd user services (like
  # kanshi/swayidle/waybar/swaync in default.nix), instead of backgrounding
  # them from sway-autostart. Two problems that fixes at once: a plain
  # `exec ... &` has no process supervision, so sway-autostart had to pkill
  # leftovers by hand on every sway restart to avoid piling up duplicates --
  # systemd just restarts/replaces the one instance. And Qt apps launched
  # directly by sway (itself started by hand from the fish login shell, which
  # never sources home-manager's hm-session-vars.sh) never saw
  # QT_QPA_PLATFORMTHEME / QT_STYLE_OVERRIDE, so syncthingtray rendered
  # unthemed -- confirmed live via /proc/<pid>/environ. A systemd user unit
  # instead inherits systemd --user's own manager environment, which does
  # have those vars (`systemctl --user show-environment`), the same reason
  # flameshot's QT_QPA_PLATFORM=xcb override used to work reliably as a unit
  # rather than a script line.
  #
  # blueman is not here: its tray icon doesn't render in swaybar at all (SNI
  # properties unsupported -- see config.nix), so it's launched on demand via
  # the $mod+b keybind instead of autostarted.
  systemd.user.services.nm-applet = {
    Unit.PartOf = [ "sway-session.target" ];
    Install.WantedBy = [ "sway-session.target" ];
    Service = {
      ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet";
      Restart = "on-failure";
    };
  };

  systemd.user.services.syncthingtray = lib.mkIf nixosConfig.services.syncthing.enable {
    Unit.PartOf = [ "sway-session.target" ];
    Install.WantedBy = [ "sway-session.target" ];
    Service = {
      ExecStart = "${pkgs.unstable.syncthingtray}/bin/syncthingtray --wait";
      Restart = "on-failure";
    };
  };
}
