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

  # The user whose home the shared mcp.json lives under (see default.nix).
  effectiveUser = cfg._effectiveUser;

  # obra/superpowers + DietrichGebert/ponytail sources, shared with default.nix
  plugins = import ./plugins.nix { inherit pkgs; };
  superpowers = plugins.superpowers;
  ponytail = plugins.ponytail;

  # Claude bundled with the shared mcp.json baked in. Same symlinkJoin +
  # wrapProgram pattern the module uses for pi.
  #
  # `node` is added to PATH because ponytail's plugin hooks run
  # `exec node ${CLAUDE_PLUGIN_ROOT}/hooks/*.js` on SessionStart/UserPromptSubmit;
  # without node resolvable in the hook's environment those hooks error.
  # (superpowers' hook is a bash polyglot that degrades gracefully, so it needs
  # nothing extra.)
  wrappedClaude = pkgs.symlinkJoin {
    name = "claude-code-mcp";
    paths = [ pkgs.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --add-flags "--mcp-config=/home/${effectiveUser}/.pi/agent/mcp.json" \
        --prefix PATH : ${lib.makeBinPath [ pkgs.nodejs ]}
    '';
  };
in
lib.mkIf cfg.enable {
  environment.systemPackages = [ wrappedClaude ];

  home-manager.users.${effectiveUser}.home.file = {
    ".claude/settings.json".text = builtins.toJSON {
      theme = "dracula";

      # superpowers + ponytail as Claude Code plugins via local directory marketplaces.
      # Marketplace keys match repo marketplace.json (superpowers-dev, ponytail).
      extraKnownMarketplaces = {
        superpowers-dev.source = {
          source = "directory";
          path = "${superpowers}";
        };
        ponytail.source = {
          source = "directory";
          path = "${ponytail}";
        };
      };
      enabledPlugins = {
        "superpowers@superpowers-dev" = true;
        "ponytail@ponytail" = true;
      };
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
