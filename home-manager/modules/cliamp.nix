{ pkgsUnstable, pkgs, ... }:
let
  inherit (pkgs) writeShellScriptBin;
  inherit (pkgsUnstable) cliamp gopass;

  draculaTheme = {
    accent = "#bd93f9";
    bright_fg = "#f8f8f2";
    fg = "#6272a4";
    green = "#50fa7b";
    yellow = "#f1fa8c";
    red = "#ff5555";
  };
in
{
  xdg.configFile."cliamp/themes/dracula.toml".source =
    (pkgs.formats.toml { }).generate "dracula-theme"
      draculaTheme;

  home.packages = [
    (writeShellScriptBin "cliamp" ''
      export NAVIDROME_URL=https://sonic.xsfx.name
      export NAVIDROME_USER=admin
      export NAVIDROME_PASS=$(${gopass}/bin/gopass show -o websites/sonic.xsfx.name/admin)

      exec ${cliamp}/bin/cliamp --theme dracula --visualizer Scatter "$@"
    '')
  ];
}
