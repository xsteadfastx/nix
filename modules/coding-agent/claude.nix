# Claude Code integration for the coding-agent module.
#
# Claude here shares a *single* MCP config with pi: the module writes the
# resolved server set to ~/.pi/agent/mcp.json (see ./default.nix), and this
# file bundles a `claude` wrapped with `--mcp-config=<that file>`. Claude's
# `--mcp-config` consumes the exact `{"mcpServers":{...}}` schema pi emits, so
# adding a server to `xsfx.codingAgent.mcpServers` feeds both agents at once.
# The `=`-form keeps the variadic flag from eating the user's own args, and the
# absence of `--strict-mcp-config` preserves Claude's own connectors (claude.ai).
#
# The shared ECC skills/agents/commands/rules live in ./skills.nix; this file
# is only the wrapped binary and Claude's own theme/settings.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.xsfx.codingAgent;

  # Claude bundled with the shared mcp.json baked in. Same symlinkJoin +
  # wrapProgram pattern the module uses for pi.
  wrappedClaude = pkgs.symlinkJoin {
    name = "claude-code-mcp";
    paths = [ pkgs.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --add-flags "--mcp-config=/home/${cfg.user}/.pi/agent/mcp.json"
    '';
  };
in
lib.mkIf cfg.enable {
  environment.systemPackages = [ wrappedClaude ];

  home-manager.users.${cfg.user}.home.file = {
    ".claude/settings.json".text = builtins.toJSON {
      theme = "dracula";
    };

    ".claude/themes/dracula.json".text = builtins.toJSON {
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
  };
}
