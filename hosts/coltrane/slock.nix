{ pkgs, ... }:
let
  blurPatch = pkgs.fetchurl {
    url = "https://tools.suckless.org/slock/patches/blur-pixelated-screen/slock-blur_pixelated_screen-1.4.diff";
    hash = "sha256-ByVNA4pzHuFngfE7pbp32pIApOjgJqMKXzZ09jK55C4=";
  };

  slock-pixel = pkgs.slock.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.imlib2 ];

    postPatch =
      (old.postPatch or "")
      + "\n"
      + ''
        patch -p1 --fuzz=3 < ${blurPatch}
        sed -i \
          -e 's|^#define BLUR$|//#define BLUR|' \
          -e 's|^//#define PIXELATION$|#define PIXELATION|' \
          -e 's|pixelSize=0|pixelSize=20|' \
          config.def.h
      '';
  });

  lock = pkgs.writeShellScriptBin "lock" ''
    # ponytail: 1 i3-msg round-trip, not 3 (was ~1s lid-close delay)
    ws=$(${pkgs.i3}/bin/i3-msg -t get_workspaces)
    printf '%s' "$ws" | ${pkgs.jq}/bin/jq -r '.[] | "\(.name) \(.output)"' > /run/user/1000/autorandr-ws-layout
    printf '%s' "$ws" | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name' > /run/user/1000/autorandr-current-ws
    printf '%s' "$ws" | ${pkgs.jq}/bin/jq -r '.[] | select(.visible and (.focused | not)) | "\(.output) \(.name)"' > /run/user/1000/autorandr-visible-ws
    # ponytail: release logind sleep-lock fd (set via --transfer-sleep-lock) after snapshot written
    if [ -n "$XSS_SLEEP_LOCK_FD" ]; then eval "exec ''${XSS_SLEEP_LOCK_FD}>&-"; fi
    /run/wrappers/bin/slock
    ${pkgs.xrandr}/bin/xrandr --auto
    ${pkgs.autorandr}/bin/autorandr --change
  '';
in
{
  security.wrappers.slock = {
    source = "${slock-pixel}/bin/slock";
    setuid = true;
    owner = "root";
    group = "root";
  };

  programs.xss-lock = {
    enable = true;
    # ponytail: transfer sleep-lock fd to the locker so it gates suspend, not xss-lock
    extraOptions = [ "--transfer-sleep-lock" ];
    lockerCommand = "${lock}/bin/lock";
  };
}
