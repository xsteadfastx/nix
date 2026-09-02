{ config, ... }:
{
  codingAgent.enable = true;

  # Per-host soul layer: appended to the module's shared default soul
  # (modules/coding-agent/soul.md) and written to both ~/.pi/agent/AGENTS.md
  # and ~/.claude/CLAUDE.md. This is the machine-wide context that used to
  # live by hand in ~/.claude/CLAUDE.md.
  codingAgent.soulExtra = ''
    ## Hard rules (non-negotiable)

    - **NEVER use `git commit --no-verify`** (or any flag that skips pre-commit
      hooks: `--no-verify`, `-n`, `--no-gpg-sign`-style bypasses, `git push
      --no-verify`, `HUSKY=0`, etc.). Pre-commit hooks exist for a reason; if a
      hook fails, fix the root cause or surface it to the user — never bypass.
      This is absolute; do not rationalize "just this once".
    - **NEVER `git push` yourself.** You may commit locally (never bypassing
      hooks), but never push to any remote — never `git push`, never open a PR
      or trigger a push on the user's behalf. The user alone decides what
      leaves the machine. If you think a push is needed, surface it and let
      the user run it.
    - **NEVER deploy for yourself.** You may build, test, and prepare a
      deployment, but never run the deploy itself — no `nixos-rebuild switch`,
      no `kubectl apply`, no `docker push`/`docker compose up`, no `terraform
      apply`, no `colmena apply`, no `systemctl restart` of a service, no
      production mutation of any kind. The user alone decides when and how something goes live. If a
      deploy is needed, surface it and let the user run it.

    ## Playwright MCP — driving the already-open Chromium

    The `playwright` MCP server on this machine runs in **extension mode** and
    drives your already-open Chromium (**Profile 1**), reusing your logged-in
    sessions. The configuration is defined and explained in
    `~/nix/hosts/coltrane/coding-agent.nix` (see `~/nix/CLAUDE.md` →
    "Playwright Extension Mode" for the full reasoning/troubleshooting).

    Operational rules when using `playwright` tools:

    - **First browser call of a session**: the server opens the extension's
      `connect.html` in your *running* Chromium (via `--executable-path` +
      `PWTEST_EXTENSION_USER_DATA_DIR` singleton-forwarding), and the installed
      Playwright Extension bridges the MCP server to your logged-in tab.
      **Approve the connect page** once per session; subsequent calls reuse the
      connection.
    - **If a *fresh* temp-profile browser opens instead of using your existing
      one** (the "opens a new browser" bug): the nixpkgs `playwright-mcp`
      wrapper forced `PLAYWRIGHT_MCP_ISOLATED=1` (it does so whenever
      `PLAYWRIGHT_MCP_USER_DATA_DIR` is unset), and since playwright-mcp 0.0.76
      `isolated` is checked *before* `extension`, so it wins and disables
      extension mode. **Fix (in `~/nix`)**: set `PLAYWRIGHT_MCP_USER_DATA_DIR`
      in the server env (a tmpfs sentinel path; `PLAYWRIGHT_MCP_ISOLATED=0`
      alone does NOT work — the wrapper re-forces it). See `~/nix/CLAUDE.md` →
      "Playwright Extension Mode". After editing: `sudo nixos-rebuild switch`,
      then **restart pi** — a lazy MCP reconnect does *not* respawn the server
      with new env.
    - **Extension must be installed in Profile 1** (Web Store id
      `mmlmfjhmonkocbjadbfplnigmagldckm`). Home Manager's
      `programs.chromium.extensions` only seeds a *fresh* profile, so on the
      pre-existing profile it must be installed once by hand from the Chrome Web
      Store.
    - **No "accept all tokens" mode.** Extension mode does a strict equality
      check on a per-profile `PLAYWRIGHT_MCP_EXTENSION_TOKEN`; we use **manual
      approval** (no token configured). Sending a *wrong* token hard-errors —
      worse than sending none.
    - **A killed `playwright-mcp` process is not auto-respawned** by pi's MCP
      reconnect (it only refreshes cached tool metadata). Restart pi to get a
      fresh server.

    ### Driving framed/JS-heavy apps
    The a11y `browser_snapshot` does not cross `<frame>`/`<iframe>` boundaries.
    For framed apps (e.g. legacy enterprise portals), use `browser_evaluate` to
    read `frame[name=...].contentDocument` (same-origin) and drive the frame's
    DOM directly — enumerate frames, read their rows/inputs, and set field values
    with `input`/`change` events before triggering the page's save handler.
  '';

  # Auto-discover models from the live ollama servers on every pi/claude
  # launch (context windows, reasoning, vision are derived from the API,
  # not hand-maintained). The local server caps context at 32768 (its
  # OLLAMA_CONTEXT_LENGTH); wobcom serves full native context.
  codingAgent.ollamaServers = [
    {
      name = "ollama-local";
      baseUrl = "http://127.0.0.1:11434/v1";
      apiKey = "ollama";
    }
    {
      name = "ollama-wobcom";
      baseUrl = "http://ollama.service.wobcom.de:11434/v1";
      apiKey = "ollama";
    }
  ];
  codingAgent.settings = {
    autoCompactionEnabled = true;
    defaultProvider = "ollama-wobcom";
    defaultModel = "gemma4:31b";
    theme = "dracula";
  };

  # MCP servers. A bare entry is enough for non-secret servers: the module's
  # registry resolves `bin` and `command` from pkgs. Grafana needs its sops
  # secrets injected — any `*_FILE` env var is auto-translated into the real
  # var (suffix stripped) at exec time (modules/coding-agent/wrapper.nix).
  # Calls are locked read-only via `--disable-write`.
  # MCP servers via the declarative catalog. `git`, `nixos`, `context7` and
  # `sequential-thinking` are enabled by default (non-secret, hardware-
  # agnostic), so they need no entry here. Secret-bound and infra servers are
  # enabled explicitly below; grafana/confluence/youtrack/hemingway are bespoke
  # and stay as raw `extra` entries.
  codingAgent.mcpServers = {
    github = {
      enable = true;
      tokenFile = config.sops.secrets."gh-token".path;
    };
    playwright = {
      enable = true;
      chromePath = "/home/marv/.nix-profile/bin/chromium";
      userDataDir = "/home/marv/.config/chromium";
    };
    memory = {
      enable = true;
      # Absolute (fs.writeFile doesn't mkdir/expand ~).
      filePath = "/home/marv/.pi/agent/memory.jsonl";
    };
    # Self-ingesting session memory: indexes pi+claude transcripts, serves
    # search_memories/store_memory/refresh to both agents via the shared mcp.json.
    # embedUrl = local ollama for semantic recall (falls back to hashed embedder
    # if unreachable). dataDir/sessionsPaths use the module defaults (upstream
    # activity-mcp now expands `~` and ingests async, so they're safe).
    activity = {
      enable = true;
      # Semantic recall via local ollama (nomic-embed-text; hardcoded model) —
      # always reachable, no network hop. Falls back to hashed embedder if down.
      embedUrl = "http://127.0.0.1:11434/v1";
    };
    sshPostgres."hemingway-barletta" = {
      enable = true;
      host = "barletta";
      db = "hemingway";
    };
    sshPostgres."chirpas-kirchart" = {
      enable = true;
      host = "kirchart";
      db = "chirpas";
    };
    sshPostgres."chirpns-kirchart" = {
      enable = true;
      host = "kirchart";
      db = "chirpns";
    };
    sshRedis.kirchart = {
      enable = true;
      host = "kirchart";
    };
    # Hemingway MCP: in-process /mcp on the deployed API (StreamableHTTP,
    # behind Caddy basic_auth). httpBasic builds the Basic auth header via
    # mcp-proxy; the var names match hemingway's existing env so mcp.json is
    # unchanged.
    httpBasic.hemingway = {
      enable = true;
      urlFile = config.sops.secrets."mcp-hemingway-url".path;
      usernameFile = config.sops.secrets."mcp-hemingway-username".path;
      passwordFile = config.sops.secrets."mcp-hemingway-password".path;
      command = "hemingway-mcp";
      urlVar = "HEMINGWAY_SERVICES_API";
      userVar = "HEMINGWAY_MCP_USERNAME";
      passVar = "HEMINGWAY_MCP_PASSWORD";
      urlSuffix = "/mcp";
    };

    # HTTP token/PAT servers (bearer auth, distinct from hemingway's basic
    # auth). The registry maps the catalog name to bin/command; only args +
    # env differ per host. secretEnv carries the *_FILE sops paths (auto-\
    # injected by the secret wrapper); extraEnv holds plain env (GRAFANA_ORG_ID).
    httpToken = {
      grafana-viz-mon = {
        enable = true;
        args = [
          "--disable-write"
          "-debug"
        ];
        secretEnv = {
          GRAFANA_URL_FILE = config.sops.secrets."mcp-grafana-url".path;
          GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = config.sops.secrets."mcp-grafana-token".path;
        };
        extraEnv.GRAFANA_ORG_ID = "1";
      };
      grafana-viz = {
        enable = true;
        args = [ "--disable-write" ];
        secretEnv = {
          GRAFANA_URL_FILE = config.sops.secrets."mcp-grafana-viz-url".path;
          GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = config.sops.secrets."mcp-grafana-viz-token".path;
        };
        extraEnv.GRAFANA_ORG_ID = "1";
      };
      # Confluence Data Center, read-only via PAT.
      confluence = {
        enable = true;
        args = [ "--read-only" ];
        secretEnv = {
          CONFLUENCE_URL_FILE = config.sops.secrets."mcp-confluence-url".path;
          CONFLUENCE_PERSONAL_TOKEN_FILE = config.sops.secrets."mcp-confluence-token".path;
        };
      };
      # YouTrack remote MCP over StreamableHTTP, Bearer token via mcp-proxy.
      youtrack = {
        enable = true;
        args = [
          "--transport"
          "streamablehttp"
          "$YOUTRACK_URL"
        ];
        secretEnv = {
          YOUTRACK_URL_FILE = config.sops.secrets."mcp-youtrack-url".path;
          API_ACCESS_TOKEN_FILE = config.sops.secrets."mcp-youtrack-token".path;
        };
      };
    };

    # NetBox MCP (netboxlabs/netbox-mcp-server): read-only REST API. URL is a
    # sops secret, so inject via NETBOX_URL_FILE (secret wrapper strips _FILE).
    netbox = {
      enable = true;
      tokenFile = config.sops.secrets."mcp-netbox-token".path;
      extraEnv.NETBOX_URL_FILE = config.sops.secrets."mcp-netbox-url".path;
    };
  };
}
