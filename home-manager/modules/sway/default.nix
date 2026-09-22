{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  # Pins workspaces to outputs by identity (EDID/model), NOT position — so it's
  # independent of the connector names xe/MST shuffles around. Arrangement
  # (modes + positions) is kanshi's job (see services.kanshi below); this only
  # moves workspaces: ws1 -> middle, ws2 -> laptop (left), ws3 -> right.
  sway-outputs = pkgs.writeShellScriptBin "sway-outputs" ''
    set -euo pipefail
    jq=${pkgs.jq}/bin/jq
    swaymsg=${pkgs.sway}/bin/swaymsg
    json="$($swaymsg -t get_outputs -r)"

    # laptop = the embedded panel (eDP-*); middle = Samsung SMB2440 (sway reports
    # the make as "Samsung Electric Company", so match on the model); right = the
    # remaining external (the anonymous small TV).
    laptop="$($jq -r '[.[] | select(.active) | select(.name | startswith("eDP")) | .name][0] // empty' <<<"$json")"
    exts="$($jq -r '[.[] | select(.active) | select(.name | startswith("eDP") | not) | select(.name != "HEADLESS-1") | {name, model}]' <<<"$json")"
    middle="$($jq -r '[.[] | select(.model == "SMB2440") | .name][0] // empty' <<<"$exts")"
    if [ -n "$middle" ]; then
      right="$($jq -r --arg m "$middle" '[.[] | select(.name != $m) | .name][0] // empty' <<<"$exts")"
    else
      # no Samsung (e.g. work, monitors unknown): fall back to connector order
      middle="$($jq -r '.[0].name // empty' <<<"$exts")"
      right="$($jq -r '.[1].name // empty' <<<"$exts")"
    fi

    # Move workspaces: sway auto-creates one per output in connector order, so
    # `workspace N output X` alone only sets the default and wouldn't relocate
    # them. Restore focus afterwards so a hotplug doesn't jump your view.
    focused="$($jq -r '[.[] | select(.focused) | .name][0] // empty' <<<"$($swaymsg -t get_workspaces -r)")"
    [ -n "$laptop" ] && swaymsg "workspace 2; move workspace to output \"$laptop\"" 2>/dev/null || true
    [ -n "$middle" ] && swaymsg "workspace 1; move workspace to output \"$middle\"" 2>/dev/null || true
    [ -n "$right" ] && swaymsg "workspace 3; move workspace to output \"$right\"" 2>/dev/null || true
    [ -n "$focused" ] && swaymsg "workspace \"$focused\"" 2>/dev/null || true
  '';
in
lib.mkIf cfg.x11 {
  xdg.configFile."sway/config".source = ./config;

  # Bind every Wayland user service (kanshi, swayidle, …) to sway-session.target
  # instead of graphical-session.target. Home Manager's default target is
  # started by NixOS *before* sway (the non-systemd-aware session wrapper starts
  # nixos-fake-graphical-session.target), so a condition on WAYLAND_DISPLAY is
  # evaluated with no compositor around and the service is skipped for the whole
  # session. The sway config starts sway-session.target right after importing
  # the env (it includes /etc/sway/config.d/nixos.conf).
  wayland.systemd.target = "sway-session.target";

  # Output arrangement via EDID-matched profiles (the Wayland autorandr). kanshi
  # applies the profile whose outputs are all present, on every hotplug — so the
  # xe/MST connector-name churn no longer matters.
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile = {
          name = "home";
          outputs = [
            {
              criteria = "LG Display 0x078B Unknown";
              mode = "1920x1200@120Hz";
              position = "0,0";
            }
            {
              criteria = "Samsung Electric Company SMB2440 H9XZ806373";
              mode = "1920x1080@60Hz";
              position = "1920,0";
            }
            {
              criteria = "Avolites Ltd HDTV Unknown";
              mode = "1360x768@60Hz";
              position = "3840,0";
            }
          ];
        };
      }
      {
        profile = {
          name = "mobile";
          outputs = [
            {
              criteria = "LG Display 0x078B Unknown";
              mode = "1920x1200@120Hz";
              position = "0,0";
            }
          ];
        };
      }
    ];
  };

  # Flameshot (screenshot editor) with its tray applet, run via home-manager's
  # systemd service so the applet is there after login and clicking it opens the
  # capture launcher. Flameshot 14 defaults to the xdg-desktop-portal capture
  # path, which is the part that's broken on wlroots; the grim adapter shells out
  # to the grim we install, so capture works with no portal. The tray icon shows
  # in swaybar (1.12 has a system tray). The hotkeys below call `flameshot
  # screen …` directly, so the applet is optional for them.
  services.flameshot = {
    enable = true;
    settings.General = {
      useGrimAdapter = true;
      disabledGrimWarning = true;
      disabledTrayIcon = false;
      showStartupLaunchMessage = false;
      # Carried over from the hand-written ~/.config/flameshot/flameshot.ini that
      # predates this module (HM refuses to clobber it, so it is moved aside
      # once): these two are the user's own preferences, not module defaults.
      drawColor = "#00ffff";
      contrastOpacity = 188;
      savePath = "/home/marv/tmp";
    };
  };

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
      color = "000000";
      inside-color = "00000000";
      ring-color = "6272a4ff";
      ring-ver-color = "8be9fdff";
      ring-wrong-color = "ff5555ff";
      keyhl-color = "bd93f9ff";
      bshl-color = "ff79c6ff";
      separator-color = "00000000";
      line-color = "00000000";
      text-color = "f8f8f2ff";
      indicator-radius = 110;
      indicator-thickness = 8;
      font = "JetBrainsMono Nerd Font";
      clock = true;
      timestr = "%H:%M:%S";
      datestr = "%A, %-d. %B";
      # swaylock-effects
      effect-vignette = "0.5:0.5";
      show-failed-attempts = true;
    };
  };

  home.packages = [
    pkgs.blueman
    # Wayland output-arrangement GUI (arandr is X11-only — no xrandr under sway).
    pkgs.wdisplays
    # Wayland screenshot stack (flameshot's X11 capture path doesn't work under
    # sway): grim captures, slurp selects a region, wl-copy puts it on the
    # clipboard. satty annotates if wanted (`grim -g "$(slurp)" - | satty -f -`).
    pkgs.grim
    pkgs.slurp
    pkgs.wl-clipboard
    sway-outputs
    (pkgs.writeShellScriptBin "sway-autostart" ''
      set -u
      # Kill leftovers from a previous session so tray applets don't pile up
      # across sway restarts (dunst/nm-applet/blueman/syncthingtray/flameshot).
      for app in dunst nm-applet blueman-applet blueman-tray syncthingtray flameshot; do
        pkill -x "$app" 2>/dev/null || true
      done
      sleep 0.3

      ${pkgs.dunst}/bin/dunst &
      ${pkgs.networkmanagerapplet}/bin/nm-applet &
      ${lib.optionalString nixosConfig.services.syncthing.enable ''
        ${pkgs.unstable.syncthingtray}/bin/syncthingtray --wait &
      ''}

      # pin workspaces once, then re-pin on every monitor hotplug (kanshi
      # meanwhile owns the actual output arrangement)
      sway-outputs
      (${pkgs.sway}/bin/swaymsg -t subscribe '["output"]' | while read -r _; do sway-outputs; done) &
    '')
  ];

  # rofi + dunst configs are shared via home-manager/modules/desktop.
}
