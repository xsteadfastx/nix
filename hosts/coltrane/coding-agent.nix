{ config, pkgs, ... }:
let
  # marv's uid, for the tmpfs XDG runtime path used by the playwright MCP env
  # below. Derived from the user config when a uid is pinned there; falls back
  # to 1000 (the auto-allocated value on this single-user host) because
  # isNormalUser leaves `uid` null at eval time.
  marvUid = if config.users.users.marv.uid != null then config.users.users.marv.uid else 1000;

  # barletta's postgres is not exposed on the network, so this wrapper opens an
  # SSH forward to it bound to the MCP's lifetime, then runs postgres-mcp
  # against it. marv's key auth to barletta is passwordless and inherited from
  # the agent's env (a systemd unit wouldn't see SSH_AUTH_SOCK). No DB role,
  # password or sops secret is needed, so the connection string is inlined.
  #   * We forward barletta's postgres UNIX SOCKET (/run/postgresql/.s.PGSQL.5432)
  #     into a per-instance temp dir, NOT a fixed TCP port. A fixed local port
  #     (was 5433) can only be bound by ONE client: with both pi and Claude
  #     sharing mcp.json, the second one's `ssh -L` hits ExitOnForwardFailure,
  #     `set -e` aborts the wrapper, postgres-mcp never starts and that client
  #     dies with `-32000 Connection closed`. A fresh `mktemp -d` socket dir per
  #     instance lets them run concurrently. It also sidesteps the IPv4/IPv6
  #     gotcha of the TCP path (barletta resolved `localhost` -> ::1, missing the
  #     IPv4 trust rule) — the socket hits pg_hba `local all all trust` directly.
  #   * Connect as `postgres` (superuser), NOT the `readonly` role: `readonly`
  #     has no data grants on this instance and can't be fixed here — barletta's
  #     hemingway DB is a read-only REPLICA (secondary of gerwer,
  #     pg_is_in_recovery=t), so GRANTs can't run on it. The socket's
  #     `local all all trust` rule grants the whole cluster as any role, so we
  #     take superuser for full read access across every DB, not just what the
  #     app-owner role can see. Reads are safe regardless: the replica is
  #     physically read-only AND `--access-mode restricted` rejects writes at
  #     parse time.
  #   * Long/full-scan reads may fail with "canceling statement due to conflict
  #     with recovery" — a standby replay-conflict artifact (barletta's
  #     max_standby_streaming_delay / hot_standby_feedback), affecting ANY read
  #     client on this replica. Tune it on barletta (infrastructure repo), not here.
  #   * `ssh -f` returns only once the forward is up (ExitOnForwardFailure), so
  #     postgres-mcp never races a not-yet-bound socket.
  #   * postgres-mcp runs in the FOREGROUND — NOT backgrounded. A backgrounded
  #     job in a non-interactive shell has its stdin redirected to /dev/null
  #     (POSIX async-list rule), which severs the MCP client's stdio so the
  #     server never receives `initialize` and the client fails with -32000. It
  #     is not `exec`'d either, so the EXIT trap still fires to close the tunnel
  #     and remove the socket dir when the MCP exits (client EOF, or SIGTERM
  #     which the foreground child receives directly).
  postgresHemingwayBarletta = pkgs.writeShellApplication {
    name = "postgres-hemingway-barletta";
    runtimeInputs = [
      pkgs.openssh
      pkgs.postgres-mcp
    ];
    text = ''
      CTL="$(mktemp -u)"
      SOCKDIR="$(mktemp -d)"
      cleanup() {
        ssh -S "$CTL" -O exit barletta 2>/dev/null || true
        rm -rf "$SOCKDIR"
      }
      trap cleanup EXIT

      ssh -f -N -M -S "$CTL" -o ExitOnForwardFailure=yes \
        -L "$SOCKDIR/.s.PGSQL.5432:/run/postgresql/.s.PGSQL.5432" barletta

      postgres-mcp --access-mode restricted \
        "postgresql://postgres@/hemingway?host=$SOCKDIR"
    '';
  };

  # Hemingway MCP: v0.89.17+ hosts the MCP server in-process at /mcp on the
  # deployed API (StreamableHTTP), behind the same Caddy basic_auth as the rest
  # of the API. mcp-proxy bridges that remote endpoint to stdio; the wrinkle is
  # that mcp-proxy has no native basic-auth option (only `-H KEY VALUE` or the
  # `API_ACCESS_TOKEN` Bearer shortcut), so this wrapper builds the
  # `Authorization: Basic <base64(user:pass)>` header from the HEMINGWAY_*
  # secrets and execs mcp-proxy with it.
  #   * `runtimeInputs` pins coreutils (base64) + mcp-proxy so the wrapper is
  #     self-contained regardless of the launching shell's PATH (a dev shell
  #     or bare systemd context may not put coreutils first).
  #   * The real env vars (HEMINGWAY_SERVICES_API / _USERNAME / _PASSWORD) are
  #     already exported by the module's secret wrapper (wrapper.nix), which
  #     cats each *_FILE into the real var and unsets the *_FILE var before
  #     exec'ing this wrapper. So this wrapper only consumes the real vars.
  #   * The header is built as a shell variable and passed as a SINGLE argv
  #     element to mcp-proxy (`-H Authorization "$AUTH"`); doing it inline in an
  #     mcp.json arg via `$(...)` does NOT work — the module's wrapper eval-execs
  #     with `eval exec ... "\$@"`, and the nested double-quotes inside the
  #     command substitution ("$HEMINGWAY_MCP_USERNAME") close the outer
  #     double-quote during eval's re-parse, splitting `Basic` from the b64 into
  #     two argv elements and breaking mcp-proxy's arg parsing.
  #   * The stdio `hemingway mcp` command still exists for local/off-host use but
  #     is no longer wired into the agent.
  hemingwayMcp = pkgs.writeShellApplication {
    name = "hemingway-mcp";
    runtimeInputs = [
      pkgs.mcp-proxy
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail
      AUTH="Basic $(printf '%s:%s' "$HEMINGWAY_MCP_USERNAME" "$HEMINGWAY_MCP_PASSWORD" | base64 -w0)"
      exec mcp-proxy --transport streamablehttp -H Authorization "$AUTH" "$HEMINGWAY_SERVICES_API/mcp"
    '';
  };
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
    # Read-only postgres MCP against barletta's `hemingway` DB. Keyed by
    # host+DB (like the two grafana instances) since the key prefixes every tool
    # name and a bare `postgres` wouldn't scale to a second DB. `bin` is the
    # SSH-tunnel wrapper (postgres isn't exposed on the network); `command` must
    # match the wrapper's binary name so the adapter execs it. No env/secret:
    # the wrapper connects passwordlessly via barletta's localhost trust rule
    # (see the wrapper comment above).
    "postgres-hemingway-barletta" = {
      bin = postgresHemingwayBarletta;
      command = "postgres-hemingway-barletta";
    };
    # Hemingway MCP: v0.89.17+ hosts the MCP server in-process at /mcp on the
    # deployed API (StreamableHTTP, behind the same Caddy basic_auth as the
    # rest of the API). `hemingwayMcp` (bespoke wrapper in the `let` above)
    # bridges it to stdio via mcp-proxy, building the `Authorization: Basic
    # <base64(user:pass)>` header from the HEMINGWAY_* creds (mcp-proxy has no
    # native basic-auth option). The three sops secrets are reused unchanged:
    # HEMINGWAY_SERVICES_API (API base, e.g. https://api.smartmetering.service
    # .wobcom.de) -> the wrapper appends /mcp; HEMINGWAY_MCP_USERNAME +
    # HEMINGWAY_MCP_PASSWORD -> base64'd into the header. The module's secret
    # wrapper cats each *_FILE into the real var and unsets the *_FILE var
    # before exec'ing hemingwayMcp, which then reads the real vars.
    hemingway = {
      bin = hemingwayMcp;
      command = "hemingway-mcp";
      env = {
        HEMINGWAY_SERVICES_API_FILE = config.sops.secrets."mcp-hemingway-url".path;
        HEMINGWAY_MCP_USERNAME_FILE = config.sops.secrets."mcp-hemingway-username".path;
        HEMINGWAY_MCP_PASSWORD_FILE = config.sops.secrets."mcp-hemingway-password".path;
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
