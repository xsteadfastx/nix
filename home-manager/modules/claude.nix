{
  nixosConfig,
  pkgsUnstable,
  lib,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.work {
  home.packages = [ pkgsUnstable.claude-code ];

  home.file.".claude/settings.json".text = builtins.toJSON {
    theme = "dracula";
  };

  home.file.".claude/themes/dracula.json".text = builtins.toJSON {
    name = "Dracula";
    base = "dark";
    overrides = {
      claude = "#bd93f9";
      error = "#ff5555";
      success = "#50fa7b";
      warning = "#ffb86c";
      diffAdded = "#50fa7b";
      diffRemoved = "#ff5555";
    };
  };
}
