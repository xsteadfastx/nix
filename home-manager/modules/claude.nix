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

  customRules = pkgs.runCommand "custom-rules" { } ''
        mkdir -p $out
        cp -r ${ecc-src}/rules/* $out/
        cat <<EOF > $out/visual-context.md
    # Visual Context Protocol
    Whenever the user runs the \`crush-img\` command or mentions a "pasted image", "clipboard image", or "screenshot", the assistant MUST immediately attempt to \`view\` the file at /run/user/1000/crush_clipboard.png.
    Do not wait for the user to explicitly ask what is in the image.
    Analyze the visual evidence to provide immediate, context-aware feedback or debugging help.
    EOF
  '';
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
  home.file.".claude/rules".source = customRules;
  home.file.".claude/skills".source = "${ecc-src}/skills";
}
