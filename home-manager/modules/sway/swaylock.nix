{
  pkgs,
  lib,
  nixosConfig,
  ...
}:
let
  cfg = nixosConfig.features;

  # swaylock takes bare uppercase hex, the palette table (statusbar.nix) holds
  # the spec spellings.
  statusbar = import ../../lib/statusbar.nix { inherit lib; };
  hex = name: lib.toUpper (lib.removePrefix "#" statusbar.palette.${name});
in
lib.mkIf cfg.desktop {
  # swayidle as a systemd user service (auto-restart).
  services.swayidle = {
    enable = true;
    # Timeouts are seconds of input inactivity. swayidle skips them while a
    # client holds an idle-inhibit (video playback, browser fullscreen), so a
    # running film never blanks the screen out from under you.
    timeouts = [
      {
        timeout = 300;
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
      {
        # Screen off 5 min after the lock: sway's own `output * power off`.
        # `*` is quoted because swayidle runs the command through `sh -c`.
        timeout = 600;
        command = "${pkgs.sway}/bin/swaymsg \"output * power off\"";
        resumeCommand = "${pkgs.sway}/bin/swaymsg \"output * power on\"";
      }
    ];
    events = {
      before-sleep = "${pkgs.swaylock}/bin/swaylock -f";
      # power-off can survive a suspend/resume; force the outputs back on so a
      # wake doesn't land on a black screen that only lights up on a keypress.
      after-resume = "${pkgs.sway}/bin/swaymsg \"output * power on\"";
    };
  };

  # Colours from the upstream dracula/swaylock theme, on plain swaylock. The
  # theme targets swaylock-effects, but that fork is unmaintained (last push
  # 2024-03) and its `screenshot` busy-loops at 100% CPU with several outputs
  # (jirutka/swaylock-effects#46, #67): after an overnight suspend it drew the
  # ring on eDP-1 only, left the externals black and never read the password.
  # Dropped with it: clock/screenshot/blur/vignette/grace/fade-in.
  programs.swaylock = {
    enable = true;
    settings = {
      daemonize = true;
      show-failed-attempts = true;
      # The theme's `color=6272A4` (the spec's Comment), restored. The black
      # deviation was for a lock screen that sat as a flat grey-blue wall behind
      # the ring for as long as the machine was idle; swayidle now powers the
      # outputs off 600s after the lock (see the timeouts above), so the wall is
      # only on screen until then -- and after a resume, which is the same few
      # minutes.
      color = hex "comment";
      font = "JetBrainsMono Nerd Font";
      indicator-idle-visible = true;
      indicator-radius = 100;
      indicator-thickness = 20;
      line-color = hex "background";
      ring-color = hex "purple";
      inside-color = hex "background";
      key-hl-color = hex "green";
      # Fully transparent separator (8-digit hex, alpha last) -- not a palette
      # colour.
      separator-color = "00000000";
      text-color = hex "foreground";
      text-caps-lock-color = "";
      line-ver-color = hex "purple";
      ring-ver-color = hex "purple";
      inside-ver-color = hex "background";
      text-ver-color = hex "cyan";
      ring-wrong-color = hex "red";
      text-wrong-color = hex "red";
      inside-wrong-color = hex "background";
      inside-clear-color = hex "background";
      text-clear-color = hex "cyan";
      ring-clear-color = hex "cyan";
      line-clear-color = hex "cyan";
      line-wrong-color = hex "background";
      bs-hl-color = hex "cyan";
      ignore-empty-password = true;
    };
  };
}
