# Shared ECC (everything-claude-code) asset pack for the coding-agent module.
#
# One fetch (pinned by rev) provides the skills/agents/commands/rules used by
# *both* agents: Claude reads them natively from ~/.claude/*, and pi reads the
# same ~/.claude/skills via its `settings.skills` (see ./default.nix). Adding or
# bumping the pack here updates both agents at once — the same single-source
# principle as the shared mcp.json.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.xsfx.codingAgent;

  # Rev: 2026-07-01 — run `nixos-rebuild` once, paste the correct hash from the error.
  # Upstream renamed the repo everything-claude-code → ECC (same owner).
  ecc-src = pkgs.fetchFromGitHub {
    owner = "affaan-m";
    repo = "ECC";
    rev = "81af40761939056ab3dc54732fd4f562a27309d0";
    hash = "sha256-qTBoRTk+6/RG82QtPuhq/DSKeDXczUkU70Sn23gDFDs=";
  };

  # ECC rules plus our visual-context protocol appended.
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
lib.mkIf cfg.enable {
  home-manager.users.${cfg.user}.home.file = {
    ".claude/agents".source = "${ecc-src}/agents";
    ".claude/commands".source = "${ecc-src}/commands";
    ".claude/rules".source = customRules;
    ".claude/skills".source = "${ecc-src}/skills";
  };
}
