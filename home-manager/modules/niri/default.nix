{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  # wofi window switcher: `--dmenu` over `niri msg --json windows`, the same
  # shape as the sway version (sway-window-switch in ../sway/default.nix) --
  # titles to pick from, then the id of the first window with that title.
  # Covers both native Wayland and XWayland (satellite) windows, since niri
  # reports them in the same list.
  #
  # ponytail: title -> id is a first-match lookup, so two windows sharing an
  # exact title focus the first; switch to an index-prefixed list if that bites.
  niri-window-switch = pkgs.writeShellScriptBin "niri-window-switch" ''
    set -eu
    niri=${pkgs.niri}/bin/niri
    jq=${pkgs.jq}/bin/jq
    wofi=${pkgs.unstable.wofi}/bin/wofi

    windows="$($niri msg --json windows)"
    sel="$(printf '%s' "$windows" | $jq -r '
      .[] | select((.title // "") != "" and (.app_id // "") != "") | .title
    ' | $wofi --dmenu --insensitive --prompt windows)"
    [ -n "$sel" ] || exit 0
    id="$(printf '%s' "$windows" | $jq -r --arg n "$sel" '
      [.[] | select((.title // "") == $n) | .id][0] // empty
    ')"
    [ -n "$id" ] && $niri msg action focus-window --id "$id"
  '';
in
lib.mkIf cfg.desktop {
  # niri runs alongside sway: `programs.niri.enable` in
  # hosts/coltrane/configuration.nix. This module is sway's desktop ported key
  # for key -- see config.nix for what niri cannot express -- so the probe login
  # judges niri itself, not a half-furnished session.
  #
  # Not ported, and moot while sway is what actually runs: the sway-outputs /
  # kanshi arrangement -- config.nix does the same job in niri's own config, by
  # make/model/serial, so kanshi would only add a second source of truth (niri
  # implements wlr-output-management since 0.1.8, so it *would* run there) -- and
  # the workspace-to-output pinning, which has no niri equivalent at all.
  #
  # For a GUI: `wdisplays` (in home.packages via ../sway, wlr-output-management)
  # and `nwg-displays` (0.4.0+ writes niri KDL) both work. They only apply
  # settings -- the config above stays the source of truth, so a GUI experiment
  # is undone by Mod+Shift+C reload.
  xdg.configFile."niri/config.kdl".source =
    let
      # Validated at build time, the way niri-flake does it for raw KDL (its
      # `validated-config-for` helper in sodiboo/niri-flake's flake.nix):
      # `niri validate` runs in the sandbox and its output *is* the config file,
      # so a syntax error fails the build instead of the login. That matters here
      # because the KDL is a string template -- Nix has no `toKDL`, and
      # `pkgs.formats` ships json/toml/yaml/ini/… but not kdl -- so nothing else
      # would catch it. `passAsFile` keeps the 400-line config out of a shell
      # string.
      config = import ./config.nix {
        inherit lib pkgs;
        windowSwitch = "${niri-window-switch}/bin/niri-window-switch";
      };
    in
    pkgs.runCommand "niri-config.kdl"
      {
        inherit config;
        passAsFile = [ "config" ];
        nativeBuildInputs = [ nixosConfig.programs.niri.package ];
      }
      ''
        niri validate -c "$configPath"
        cp "$configPath" $out
      '';

  home.packages = [ pkgs.xwayland-satellite ];

  # Starting `niri` instead of `niri-session` is the trap: the compositor comes up
  # but the systemd user manager never learns WAYLAND_DISPLAY/NIRI_SOCKET and
  # graphical-session.target never starts, so waybar/swayidle/swaync end up in
  # start-limit-hit. ~/.local/bin sits *before* /run/current-system/sw/bin in this
  # login shell's PATH, so this wrapper catches the plain name: no arguments ->
  # the session wrapper, anything else (`niri msg …`, `--session`) -> the real
  # binary. A shell function would not help: the tty1 login shell is bash, not
  # fish.
  home.file.".local/bin/niri" = {
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      if [ $# -eq 0 ]; then
          exec ${nixosConfig.programs.niri.package}/bin/niri-session
      fi
      exec ${nixosConfig.programs.niri.package}/bin/niri "$@"
    '';
  };

  # Every session-bound user unit (waybar, swayidle, the tray applets) is
  # WantedBy sway-session.target only: Home Manager's wayland.systemd.target is a
  # single value and sway needs its own, because NixOS starts
  # graphical-session.target *before* sway with no WAYLAND_DISPLAY (see
  # ../sway/default.nix). niri needs no such target -- niri.service carries
  # `Before=graphical-session.target` and `BindsTo=graphical-session.target`, so
  # in a niri session that target starts *after* the compositor is up and the
  # same units work off it unchanged.
  #
  # Adding the second WantedBy (unit lists merge) starts them in either session,
  # without touching the sway path. syncthingtray is conditional: declaring it
  # when the service is off would create a unit with no ExecStart.
  #
  # waybar stays, for the tray: every applet here (blueman, syncthingtray,
  # nm-applet, signal) is a StatusNotifierItem and needs a bar to host it.
  systemd.user.services =
    lib.genAttrs
      [
        "waybar"
        "swayidle"
        "nm-applet"
      ]
      (_: {
        Install.WantedBy = [ "graphical-session.target" ];
      })
    // lib.optionalAttrs nixosConfig.services.syncthing.enable {
      syncthingtray.Install.WantedBy = [ "graphical-session.target" ];
    };
}
