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
  # syncthingtray as a systemd user service (like
  # swayidle/wayle), instead of backgrounding it from a session script. Two problems that fixes at once: a plain
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
  # blueman and pavucontrol are gone: wayle's bluetooth and audio dropdowns do
  # pairing and per-app volumes. CLI fallback: bluetoothctl, wpctl.
  systemd.user.services.syncthingtray = lib.mkIf nixosConfig.services.syncthing.enable {
    Unit.PartOf = [ "graphical-session.target" ];
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${pkgs.unstable.syncthingtray}/bin/syncthingtray --wait";
      Restart = "on-failure";
    };
  };
}
