{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features.games;

  gamesLibrary = "$HOME/library/games";

  chdToCue = pkgs.writeShellScriptBin "chd-to-cue" ''
    set -euo pipefail
    base="''${1%.chd}"
    ${pkgs.mame-tools}/bin/chdman extractcd -i "$1" -o "$base.cue" -ob "$base.bin"
  '';

  mednafenBase = "${pkgs.mednafen}/bin/mednafen -sound.device sexyal-literal-default";

  # X11 leftover from the i3 days: xss-lock/xset controlled the X11
  # screensaver, which doesn't exist under sway -- calling xset against
  # XWayland wouldn't touch swayidle's real lock timeout at all, so that half
  # was already dead weight, not just unported. systemd-inhibit alone still
  # does real work (blocks logind's own idle/sleep action).
  # ponytail: swayidle's timeout isn't suppressed by anything here anymore --
  # gamepad input doesn't count as activity, so a controller-only session can
  # still get screen-locked mid-game. The correct fix is a client that holds
  # a Wayland idle-inhibit-unstable-v1 lock for the game's lifetime; wlinhibit
  # (nixpkgs) looks like the fit but its own README calls it "fundamentally
  # broken" on compositors with correct protocol support, so it's not wired
  # in here. Revisit if this actually bites.
  inhibit = who: cmd: ''
    ${pkgs.systemd}/bin/systemd-inhibit --who="${who}" --why="Gaming" ${cmd}
  '';

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
    ${inhibit "Dolphin" "${pkgs.dolphin-emu}/bin/dolphin-emu \"$rom\""}
  '';

  playstation = pkgs.writeShellScriptBin "playstation" ''
    set -euo pipefail
    cue=$(${pkgs.findutils}/bin/find "${gamesLibrary}" -name playstationdisc.cue | ${pkgs.fzf}/bin/fzf --preview "${pkgs.eza}/bin/eza -l {}")
    [[ -n "$cue" ]] || exit 0
    exec ${mednafenBase} "$cue"
  '';

  ps2 = pkgs.writeShellScriptBin "ps2" ''
    set -euo pipefail
    rom=$(${pkgs.findutils}/bin/find "${gamesLibrary}/playstation2" -type f | ${pkgs.fzf}/bin/fzf --preview "${pkgs.eza}/bin/eza -l {}")
    [[ -n "$rom" ]] || exit 0
    ${inhibit "PCSX2" "${pkgs.pcsx2}/bin/pcsx2-qt \"$rom\""}
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
    ps2
  ];
}
