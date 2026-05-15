{
  nixosConfig,
  pkgsUnstable,
  pkgs,
  lib,
  ...
}:
let
  cfg = nixosConfig.xsfx;

  # Rev: 2026-05-15 — run `nixos-rebuild` once, paste the correct hash from the error
  ecc-src = pkgs.fetchFromGitHub {
    owner = "affaan-m";
    repo = "everything-claude-code";
    rev = "e8e9df52a6b1cd93d454c6e539b15ee487b166ff";
    hash = "sha256-fLcrTWDAaJsuDntOrhNoy1YOhn8oE814CElpsrYOWm4=";
  };
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

  home.file.".claude/agents".source = "${ecc-src}/agents";
  home.file.".claude/commands".source = "${ecc-src}/commands";
  home.file.".claude/rules".source = "${ecc-src}/rules";
  home.file.".claude/skills".source = "${ecc-src}/skills";
}
