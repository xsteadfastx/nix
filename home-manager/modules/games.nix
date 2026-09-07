{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.xsfx.games;

  gamesLibrary = "$HOME/library/games";

  chdToCue = pkgs.writeShellScriptBin "chd-to-cue" ''
    set -euo pipefail
    base="''${1%.chd}"
    ${pkgs.mame-tools}/bin/chdman extractcd -i "$1" -o "$base.cue" -ob "$base.bin"
  '';

  mednafenBase = "${pkgs.mednafen}/bin/mednafen -sound.device sexyal-literal-default";

  n64 = pkgs.writeShellScriptBin "n64" ''
    set -euo pipefail
    rom=$(${pkgs.findutils}/bin/find "${gamesLibrary}/n64" -type f | ${pkgs.fzf}/bin/fzf --preview "${pkgs.eza}/bin/eza -l {}")
    [[ -n "$rom" ]] || exit 0
    exec ${pkgs.mupen64plus}/bin/mupen64plus --video mupen64plus-video-glide64mk2.so "$rom"
  '';

  nes = pkgs.writeShellScriptBin "nes" ''
    set -euo pipefail
    rom=$(${pkgs.findutils}/bin/find "${gamesLibrary}/nes" -type f | ${pkgs.fzf}/bin/fzf --preview "${pkgs.eza}/bin/eza -l {}")
    [[ -n "$rom" ]] || exit 0
    exec ${mednafenBase} "$rom"
  '';

  gamecube = pkgs.writeShellScriptBin "gamecube" ''
    set -euo pipefail
    rom=$(${pkgs.findutils}/bin/find "${gamesLibrary}/gamecube" -type f | ${pkgs.fzf}/bin/fzf --preview "${pkgs.eza}/bin/eza -l {}")
    [[ -n "$rom" ]] || exit 0
    # ponytail: systemd-inhibit only blocks logind idle; the screensaver is
    # xss-lock off the X11 saver, so suspend that too while playing. No exec:
    # the shell must survive to run the EXIT trap that restores the timeout
    # (xset s on would reset it to the 600s server default, not our 60s).
    timeout=$(${pkgs.xset}/bin/xset q | ${pkgs.gawk}/bin/awk '/timeout:/{print $2}')
    ${pkgs.xset}/bin/xset s off
    trap '${pkgs.xset}/bin/xset s "$timeout"' EXIT
    ${pkgs.systemd}/bin/systemd-inhibit --who="Dolphin" --why="Gaming" ${pkgs.dolphin-emu}/bin/dolphin-emu "$rom"
  '';

  playstation = pkgs.writeShellScriptBin "playstation" ''
    set -euo pipefail
    cue=$(${pkgs.findutils}/bin/find "${gamesLibrary}" -name playstationdisc.cue | ${pkgs.fzf}/bin/fzf --preview "${pkgs.eza}/bin/eza -l {}")
    [[ -n "$cue" ]] || exit 0
    exec ${mednafenBase} "$cue"
  '';
in
lib.mkIf cfg {
  programs.liliumVoyager.enable = true;

  home.packages = with pkgs; [
    chdToCue
    dolphin-emu
    gamecube
    mednafen
    mupen64plus
    n64
    nes
    pcsx2
    playstation
  ];
}
