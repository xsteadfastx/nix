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
  # swayidle as a systemd user service (auto-restart).
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${pkgs.swaylock-effects}/bin/swaylock -f";
      }
    ];
    events.before-sleep = "${pkgs.swaylock-effects}/bin/swaylock -f";
  };

  # Upstream dracula/swaylock theme, verbatim except for `font`: the theme's
  # README targets swaylock-effects (blur/vignette/screenshot/clock/indicator/
  # grace/fade-in do NOT exist in plain swaylock 1.8.x), so the package stays
  # swaylock-effects. Keys are the config-file names, hyphenated -- the
  # unhyphenated spellings (keyhl-color, ...) made swaylock exit with
  # "unrecognized option" before ever drawing a lock screen.
  # ponytail: `grace = 2` unlocks on any keypress for the first 2s (mouse/touch
  # disabled by the two grace-no-* flags). That is upstream Dracula's behaviour,
  # not a hardening regression -- drop grace if the lock must bite immediately.
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      daemonize = true;
      show-failed-attempts = true;
      clock = true;
      screenshot = true;
      effect-blur = "13x13";
      effect-vignette = "0.5:0.5";
      color = "6272A4";
      font = "JetBrainsMono Nerd Font";
      indicator = true;
      indicator-radius = 200;
      indicator-thickness = 20;
      line-color = "282A36";
      ring-color = "BD93F9";
      inside-color = "282A36";
      key-hl-color = "50FA7B";
      separator-color = "00000000";
      text-color = "F8F8F2";
      text-caps-lock-color = "";
      line-ver-color = "BD93F9";
      ring-ver-color = "BD93F9";
      inside-ver-color = "282A36";
      text-ver-color = "8BE9FD";
      ring-wrong-color = "FF5555";
      text-wrong-color = "FF5555";
      inside-wrong-color = "282A36";
      inside-clear-color = "282A36";
      text-clear-color = "8BE9FD";
      ring-clear-color = "8BE9FD";
      line-clear-color = "8BE9FD";
      line-wrong-color = "282A36";
      bs-hl-color = "8BE9FD";
      grace = 2;
      grace-no-mouse = true;
      grace-no-touch = true;
      datestr = "%a, %B %e";
      timestr = "%I:%M %p";
      fade-in = "0.4"; # string, not float: HM's toString turns 0.4 into 0.400000
      ignore-empty-password = true;
    };
  };
}
