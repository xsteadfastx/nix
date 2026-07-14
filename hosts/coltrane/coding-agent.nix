{ config, ... }:
let
  # marv's uid, for the tmpfs XDG runtime path used by the playwright MCP env
  # below. Derived from the user config when a uid is pinned there; falls back
  # to 1000 (the auto-allocated value on this single-user host) because
  # isNormalUser leaves `uid` null at eval time.
  marvUid = if config.users.users.marv.uid != null then config.users.users.marv.uid else 1000;
in
{
  xsfx.codingAgent.enable = true;

  xsfx.codingAgent.settings = {
    autoCompactionEnabled = true;
    defaultProvider = "ollama-wobcom";
    defaultModel = "gemma4:31b";
    theme = "dracula";
    skills = [ "/home/marv/.claude/skills" ];
  };

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
    # GitHub's official MCP server (github/github-mcp-server). Reuses the
    # existing `gh-token` sops secret — a PAT works for both `gh` CLI
    # (GH_TOKEN) and this server (GITHUB_PERSONAL_ACCESS_TOKEN). Default
    # toolset covers issues, pull_requests, repos, users + copilot context;
    # add `--toolsets=default,actions` if CI workflows should be reachable.
    github = {
      args = [ "stdio" ];
      env = {
        GITHUB_PERSONAL_ACCESS_TOKEN_FILE = config.sops.secrets."gh-token".path;
      };
    };
    # Grafana: two instances, same read-only binary, distinct credentials.
    # grafana-viz-mon: monitoring Grafana instance (URL/token in sops).
    grafana-viz-mon = {
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
    # grafana-viz: second Grafana instance (URL/token in sops).
    grafana-viz = {
      args = [ "--disable-write" ];
      env = {
        GRAFANA_URL_FILE = config.sops.secrets."mcp-grafana-viz-url".path;
        GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = config.sops.secrets."mcp-grafana-viz-token".path;
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

        # CRITICAL for extension mode on nixpkgs' playwright-mcp: the package's
        # bin is a wrapper that does
        #   if [ -z "$PLAYWRIGHT_MCP_USER_DATA_DIR" ]; then
        #     export PLAYWRIGHT_MCP_ISOLATED=1; fi
        # Since playwright-mcp 0.0.76 (playwright-core 1.61) the browser-mode
        # decision checks `isolated` BEFORE `extension`, so a forced
        # ISOLATED=1 silently wins over `--extension` and launches a throwaway
        # temp-profile browser (no extension, no logins) instead of bridging to
        # your running Chromium. (0.0.69 evaluated extension first, so this was
        # latent.) Setting USER_DATA_DIR non-empty makes the wrapper skip the
        # ISOLATED=1 export. The value itself is inert in extension mode: the
        # target browser is your running Chromium via the extension, so
        # playwright-mcp never launches with this dir and nothing is stored
        # here. It exists only as a sentinel to defeat the wrapper's `-z` check.
        # Point it at the tmpfs XDG runtime dir so that in the one edge case it
        # *would* be used (a fallback persistent launch if the extension never
        # connects) the profile lives in memory and is auto-cleaned on logout.
        PLAYWRIGHT_MCP_USER_DATA_DIR = "/run/user/${toString marvUid}/playwright-mcp-profile";
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
    # JetBrains ships a remote MCP server built into YouTrack itself (no
    # package to install): <instance>/mcp over StreamableHTTP. mcp-proxy
    # bridges it to stdio so the adapter spawns it like any other server.
    # The permanent token is injected via API_ACCESS_TOKEN_FILE; the module's
    # secret wrapper cats it into API_ACCESS_TOKEN, which mcp-proxy sends as
    # `Authorization: Bearer <token>`. Generate the token in YouTrack
    # (Profile → Account → Permanent Tokens, scope: YouTrack) and store it in
    # sops under `mcp-youtrack-token`.
    youtrack = {
      args = [
        "--transport"
        "streamablehttp"
        "$YOUTRACK_URL"
      ];
      env = {
        YOUTRACK_URL_FILE = config.sops.secrets."mcp-youtrack-url".path;
        API_ACCESS_TOKEN_FILE = config.sops.secrets."mcp-youtrack-token".path;
      };
    };
  };
}
