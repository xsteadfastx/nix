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

  # Colors from the upstream dracula/swaylock theme on plain swaylock. The
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
      # Deliberate deviation from the dracula theme: its #6272A4 fills all three
      # outputs with grey-blue, which reads as a washed-out wall behind the ring.
      color = "000000";
      font = "JetBrainsMono Nerd Font";
      indicator-idle-visible = true;
      indicator-radius = 100;
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
      ignore-empty-password = true;
    };
  };
}
