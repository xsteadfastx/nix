{ pkgs, ... }:
let
  inherit (pkgs) writeShellScriptBin;
  inherit (pkgs.unstable) cliamp gopass;
in
{
  home.packages = [
    (writeShellScriptBin "cliamp" ''
      export NAVIDROME_URL=https://sonic.xsfx.name
      export NAVIDROME_USER=admin
      export NAVIDROME_PASS=$(${gopass}/bin/gopass show -o websites/sonic.xsfx.name/admin)

      exec ${cliamp}/bin/cliamp --start-theme dracula --visualizer Scatter "$@"
    '')
  ];
}
