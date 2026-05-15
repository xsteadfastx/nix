{ pkgs, ... }:
let
  slockConfig = pkgs.writeText "slock-config.h" ''
    static const char *user  = "nobody";
    static const char *group = "nogroup";

    static const char *colorname[NUMCOLS] = {
      [INIT]   = "#282a36", /* background */
      [INPUT]  = "#bd93f9", /* purple — typing */
      [FAILED] = "#ff5555", /* red — wrong password */
    };

    static int failonclear = 1;
  '';

  slock-dracula = pkgs.slock.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + "\ncp ${slockConfig} config.h\n";
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
    source = "${slock-dracula}/bin/slock";
    setuid = true;
    owner = "root";
    group = "root";
  };

  programs.xss-lock = {
    enable = true;
    lockerCommand = "${lock}/bin/lock";
  };
}
