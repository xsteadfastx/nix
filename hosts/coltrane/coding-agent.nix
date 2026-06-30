{ config, ... }:
{
  xsfx.codingAgent.enable = true;

  # MCP servers. A bare entry is enough for non-secret servers: the module's
  # registry resolves `bin` and `command` from pkgs. Grafana needs its sops
  # secrets injected — any `*_FILE` env var is auto-translated into the real
  # var (suffix stripped) at exec time (modules/coding-agent/wrapper.nix).
  # Calls are locked read-only via `--disable-write`.
  xsfx.codingAgent.mcpServers = {
    nixos = { };
    git = { };
    context7 = { };
    "sequential-thinking" = { };
    grafana = {
      args = [
        "--disable-write"
        "-debug"
      ];
      env = {
        GRAFANA_URL_FILE = config.sops.secrets."mcp-grafana-url".path;
        GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = config.sops.secrets."mcp-grafana-token".path;
        GRAFANA_ORG_ID = "1";
      };
    };
    # Drives your already-open Chromium tabs via the Playwright browser
    # extension (installed in home-manager/modules/chromium.nix). Extension
    # mode sidesteps Chrome 136's refusal of --remote-debugging-port on the
    # default profile, so it reuses your logged-in sessions. You attach the
    # tabs you want automated.
    playwright = {
      args = [ "--extension" ];
    };
    # Persistent knowledge-graph memory. MEMORY_FILE_PATH must be absolute
    # (a relative path resolves against the read-only nix store) and its
    # parent must already exist (the server uses fs.writeFile, which does
    # not mkdir). ~/.pi/agent/ is created by this module's home.file entries.
    memory = {
      env = {
        MEMORY_FILE_PATH = "/home/marv/.pi/agent/memory.jsonl";
      };
    };
  };
}
