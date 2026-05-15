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
          -e 's|#define BLUR|/* #define BLUR */|' \
          -e 's|/\* #define PIXELATION \*/|#define PIXELATION|' \
          -e 's|static const int pixelSize = 0|static const int pixelSize = 20|' \
          config.def.h
      '';
  });

  lock = pkgs.writeShellScriptBin "lock" ''
    ${pkgs.i3}/bin/i3-msg -t get_workspaces | ${pkgs.jq}/bin/jq -r '.[] | "\(.name) \(.output)"' > /run/user/1000/autorandr-ws-layout
    ${pkgs.i3}/bin/i3-msg -t get_workspaces | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name' > /run/user/1000/autorandr-current-ws
    ${pkgs.i3}/bin/i3-msg -t get_workspaces | ${pkgs.jq}/bin/jq -r '.[] | select(.visible and (.focused | not)) | "\(.output) \(.name)"' > /run/user/1000/autorandr-visible-ws
    /run/wrappers/bin/slock
    ${pkgs.xorg.xrandr}/bin/xrandr --auto
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
    lockerCommand = "${lock}/bin/lock";
  };
}
