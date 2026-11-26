{
  lib,
  pkgs,
  nixosConfig,
  ...
}:
let
  cfg = nixosConfig.features;

  # Screen on/off for the idle chain. niri powers DPMS through its own action;
  # under sway this was `swaymsg output * power off`, which is what the old
  # session used to do at the same point in the chain.
  screenPower = state: "${pkgs.niri}/bin/niri msg action power-${state}-monitors";
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
        # Screen off 5 min after the lock.
        timeout = 600;
        command = screenPower "off";
        resumeCommand = screenPower "on";
      }
    ];
    events = {
      before-sleep = "${pkgs.swaylock}/bin/swaylock -f";
      # power-off can survive a suspend/resume; force the outputs back on so a
      # wake doesn't land on a black screen that only lights up on a keypress.
      after-resume = screenPower "on";
    };
  };

  # Plain swaylock, not swaylock-effects (which the old dracula/swaylock theme
  # targeted): that fork is unmaintained (last push 2024-03) and its `screenshot` busy-loops at 100% CPU with several outputs
  # (jirutka/swaylock-effects#46, #67): after an overnight suspend it drew the
  # ring on eDP-1 only, left the externals black and never read the password.
  # Dropped with it: clock/screenshot/blur/vignette/grace/fade-in.
  programs.swaylock = {
    enable = true;
    # Colours come from catppuccin.swaylock (home-manager/modules/catppuccin.nix);
    # only the behaviour flags are ours.
    settings = {
      daemonize = true;
      show-failed-attempts = true;
      font = "JetBrainsMono Nerd Font";
      indicator-idle-visible = true;
      indicator-radius = 100;
      indicator-thickness = 20;
      # Fully transparent separator (8-digit hex, alpha last) -- not a colour.
      separator-color = "00000000";
      ignore-empty-password = true;
    };
  };
}
