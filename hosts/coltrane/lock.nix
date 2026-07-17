{ pkgs, ... }:
let
  # ponytail: i3lock-color (forking), because slock can't do xss-lock's
  # --transfer-sleep-lock — it holds the delay-lock fd until unlock, so we had to
  # close it before the grab and suspend raced ahead (desktop visible on resume).
  # i3lock forks after grabbing => we close the fd at the right moment. Does no
  # DPMS (unlike xsecurelock, which killed the xe/MST topology, commit 6ab3350;
  # also archived upstream 2026-04-18).

  lock = pkgs.writeShellScript "lock" ''
    set -u

    # Snapshot i3 workspace->output layout so autorandr can restore it after unlock.
    # ponytail: 1 i3-msg round-trip, not 3 (was ~1s lid-close delay)
    ws=$(${pkgs.i3}/bin/i3-msg -t get_workspaces)
    printf '%s' "$ws" | ${pkgs.jq}/bin/jq -r '.[] | "\(.name) \(.output)"' > /run/user/1000/autorandr-ws-layout
    printf '%s' "$ws" | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name' > /run/user/1000/autorandr-current-ws
    printf '%s' "$ws" | ${pkgs.jq}/bin/jq -r '.[] | select(.visible and (.focused | not)) | "\(.output) \(.name)"' > /run/user/1000/autorandr-visible-ws

    i3lock=${pkgs.i3lock-color}/bin/i3lock
    # Dracula ring + clock. Idle=comment, verify=cyan, wrong=red, keys=purple/pink.
    opts=(
      # --composite: without it, i3lock (launched by xss-lock off the X saver)
      # grabs input but never repaints over the framebuffer, so the live desktop
      # shows through until a pointer event forces a redraw. Forces a proper draw.
      --composite
      --clock --indicator --radius=110 --ring-width=8
      --time-str="%H:%M:%S" --date-str="%A, %-d. %B"
      --time-font="JetBrainsMono Nerd Font" --date-font="JetBrainsMono Nerd Font"
      --verif-font="JetBrainsMono Nerd Font" --wrong-font="JetBrainsMono Nerd Font"
      --color=282a36 --inside-color=282a36cc
      --ring-color=6272a4ff --ringver-color=8be9fdff --ringwrong-color=ff5555ff
      --keyhl-color=bd93f9ff --bshl-color=ff79c6ff
      --time-color=f8f8f2ff --date-color=6272a4ff
      --ignore-empty-password
    )

    kill_i3lock() { ${pkgs.procps}/bin/pkill -xu "$UID" "$@" i3lock; }

    if [ -e "/dev/fd/''${XSS_SLEEP_LOCK_FD:--1}" ]; then
      # Suspend path (xss-lock --transfer-sleep-lock): the delay-lock fd is in
      # $XSS_SLEEP_LOCK_FD. Start i3lock WITHOUT that fd ({fd}<&- closes it for
      # the child only); i3lock forks after grabbing, so the command returns once
      # the screen is locked. Then close our own copy to release the delay lock
      # -> logind proceeds to suspend with the screen already locked.
      trap kill_i3lock TERM INT
      "$i3lock" "''${opts[@]}" {XSS_SLEEP_LOCK_FD}<&-
      exec {XSS_SLEEP_LOCK_FD}<&-
      while kill_i3lock -0 2>/dev/null; do ${pkgs.coreutils}/bin/sleep 0.5; done
    else
      # Manual lock (xset s activate): no sleep fd, run in foreground with -n.
      "$i3lock" -n "''${opts[@]}"
    fi

    # Re-apply external monitors + workspace layout dropped during suspend.
    ${pkgs.xrandr}/bin/xrandr --auto
    ${pkgs.autorandr}/bin/autorandr --change
  '';
in
{
  programs.i3lock = {
    enable = true; # sets up the i3lock / i3lock-color PAM services
    package = pkgs.i3lock-color;
  };

  programs.xss-lock = {
    enable = true;
    # ponytail: transfer sleep-lock fd to the locker so it gates suspend, not xss-lock
    extraOptions = [ "--transfer-sleep-lock" ];
    lockerCommand = "${lock}";
  };
}
