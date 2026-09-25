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
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
    ];
    events.before-sleep = "${pkgs.swaylock}/bin/swaylock -f";
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
      ignore-empty-password = true;
    };
  };
}
