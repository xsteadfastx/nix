{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  # fuzzel window switcher: `--dmenu` over `niri msg --json windows`, the same
  # shape as the sway version this replaced --
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
    fuzzel=${pkgs.unstable.fuzzel}/bin/fuzzel

    windows="$($niri msg --json windows)"
    sel="$(printf '%s' "$windows" | $jq -r '
      .[] | select((.title // "") != "" and (.app_id // "") != "") | .title
    ' | $fuzzel --dmenu --prompt "windows> ")"
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
  # Output arrangement lives in config.nix (niri's own blocks, matched by
  # make/model/serial); the sway-outputs script and kanshi that used to do it are
  # gone with sway. There is no workspace-to-output pinning: niri workspaces
  # belong to a monitor.
  #
  # For a GUI: `wdisplays` (home.packages, ../desktop.nix, wlr-output-management)
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

}
