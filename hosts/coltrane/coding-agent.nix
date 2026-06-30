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
    # extension (declared in home-manager/modules/chromium.nix; on a
    # pre-existing profile HM only seeds extensions on first run, so install
    # it once from the Web Store if it's missing). Extension mode sidesteps
    # Chrome 136's refusal of --remote-debugging-port on the default profile,
    # so it reuses your logged-in sessions. You attach the tabs you want
    # automated.
    playwright = {
      args = [
        "--extension"
        "--executable-path"
        "/home/marv/.nix-profile/bin/chromium"
      ];
      env = {
        # Extension mode launches a Chromium to host the connect page; point
        # it at the real binary + your existing profile so Chromium's
        # singleton forwards the connect page into the already-running
        # instance (your logged-in sessions) instead of opening a fresh
        # bundled Chromium with no extension installed.
        PWTEST_EXTENSION_USER_DATA_DIR = "/home/marv/.config/chromium";
      };
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
