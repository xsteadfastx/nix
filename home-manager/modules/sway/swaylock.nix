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

  # swaylock-effects (the fancy fork: blur, vignette, etc.). Black background
  # with the Dracula ring + clock.
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      # 8-digit RGBA, matching every other color below -- the 6-digit form
      # this had before is inconsistent with the rest of this config and is
      # the likely reason the lock screen rendered grey instead of black.
      color = "000000ff";
      inside-color = "00000000";
      ring-color = "6272a4ff";
      ring-ver-color = "8be9fdff";
      ring-wrong-color = "ff5555ff";
      # swaylock's actual flag is --key-hl-color / --bs-hl-color (hyphenated);
      # the unhyphenated names silently made every swaylock invocation exit
      # with "unrecognized option" before ever drawing a lock screen at all --
      # confirmed live via `swaylock -c 000000ff -f`. Whatever grey background
      # was seen before was never swaylock's rendering; it never ran.
      key-hl-color = "bd93f9ff";
      bs-hl-color = "ff79c6ff";
      separator-color = "00000000";
      line-color = "00000000";
      text-color = "f8f8f2ff";
      indicator-radius = 110;
      indicator-thickness = 8;
      font = "JetBrainsMono Nerd Font";
      clock = true;
      timestr = "%H:%M:%S";
      datestr = "%A, %-d. %B";
      # effect-vignette only darkens an *image* background (-i/-S); with
      # neither set here it was a no-op, dropped.
      show-failed-attempts = true;
    };
  };
}
