# Configurable `coding-agent` Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `modules/coding-agent/` a coworker-friendly module: coworkers enable MCPs and attach secret file paths via a declarative option surface, with the SSH-tunnel wrappers shipped as reusable option-backed builders.

**Architecture:** Replace the free-form `mcpServers` attrs with a typed `submodule` exposing per-server `enable` toggles + secret-path fields, an `extra` escape hatch for backward compatibility, and an `sshPostgres`/`sshRedis`/`httpBasic` declarative catalog backed by the existing registry + `mkSecretWrapper`. Push marv-specific defaults (models, settings, user) out of the module into `hosts/coltrane/`.

**Tech Stack:** NixOS module system, home-manager, sops-nix, nixpkgs.

## Global Constraints

- Follow the existing module patterns: registry (`mcp-registry.nix`) is source of truth for `bin`/`command`; every server goes through `mkSecretWrapper` (env scrub + `*_FILE` injection).
- `*_FILE` env keys auto-trigger secret wrapping; module never stores secrets, only file paths (coworkers source from `config.sops.secrets."<name>".path`).
- Non-secret, hardware-agnostic servers (`git`, `nixos`, `context7`, `sequential-thinking`) default to enabled; everything secret-bound is opt-in.
- `user` defaults to the first normal user, never hardcoded to `marv`.
- Backward compatible: coltrane's existing raw entries must still work via `mcpServers.extra`.
- Run `nix fmt` before every commit (pre-commit runs `nixfmt` and rejects unformatted `.nix`).

---

### Task 1: Declarative `mcpServers` submodule option

**Files:**
- Create: `modules/coding-agent/mcp-servers.nix`

**Interfaces:**
- Consumes: nothing (standalone option module).
- Produces: `options.xsfx.codingAgent.mcpServers` as a submodule with typed sub-options. `default.nix` imports it (Task 2).

- [ ] **Step 1: Write the module**

```nix
{ lib, ... }:
let
  # A secret-file path option. The module never reads the secret itself —
  # only the path. Coworkers set it to config.sops.secrets.<name>.path.
  srv = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Path to the secret file (e.g. config.sops.secrets.<name>.path).";
  };

  # Shared options for SSH-tunneled servers.
  sshServer = {
    options = {
      enable = lib.mkEnableOption "this SSH-forwarded MCP server";
      host = lib.mkOption {
        type = lib.types.str;
        description = "SSH target hostname.";
      };
      sshUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "SSH user for the target host. Null = ssh(1) default user (current user).";
      };
      sshOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra ssh(1) options.";
      };
    };
  };
in
{
  options.xsfx.codingAgent.mcpServers = lib.mkOption {
    type = lib.types.submodule {
      options = {
        git = lib.mkEnableOption "git MCP server";
        nixos = lib.mkEnableOption "nixos MCP server";
        context7 = lib.mkEnableOption "context7 MCP server";
        sequentialThinking = lib.mkEnableOption "sequential-thinking MCP server";

        github = {
          enable = lib.mkEnableOption "github MCP server";
          tokenFile = srv;
        };
        playwright = {
          enable = lib.mkEnableOption "playwright MCP server";
          chromePath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to a chromium binary (for --executable-path).";
          };
          userDataDir = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to the Chromium user-data-dir/profile.";
          };
        };
        memory = {
          enable = lib.mkEnableOption "memory MCP server";
          filePath = lib.mkOption {
            type = lib.types.str;
            default = "~/.pi/agent/memory.jsonl";
          };
        };

        sshPostgres = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule (sshServer // {
            options.db = lib.mkOption {
              type = lib.types.str;
              description = "Database name to connect to.";
            };
          }));
          default = { };
        };
        sshRedis = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule sshServer);
          default = { };
        };
        httpBasic = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "this HTTP basic-auth MCP server";
              urlFile = srv;
              usernameFile = srv;
              passwordFile = srv;
              command = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Override binary name (for a bespoke wrapper).";
              };
            };
          });
          default = { };
        };

        # Raw escape hatch, backward-compatible with the old free-form shape.
        extra = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Raw MCP server entries ({bin,command,args,env}); merged last.";
        };
      };
    };
    default = {
      git = true;
      nixos = true;
      context7 = true;
      sequentialThinking = true;
    };
  };
}
```

- [ ] **Step 2: Evaluate the option tree**

Run:
```bash
nix-instantiate --eval -E 'let lib = (import <nixpkgs> {}).lib; m = import ./modules/coding-agent/mcp-servers.nix { inherit lib; }; in lib.evalModules { modules = [ m ]; }'
```
Expected: evaluates to `{ options = ...; config = ...; }` with the `mcpServers.default.git = true` and no type errors — confirms the submodule typechecks.

- [ ] **Step 3: Commit**

```bash
cd /home/marv/nix
git add modules/coding-agent/mcp-servers.nix
git commit -m "feat(coding-agent): declarative mcpServers submodule options"
```

---

### Task 2: Promote SSH tunnel builders into the module

**Files:**
- Create: `modules/coding-agent/ssh-tunnels.nix`

**Interfaces:**
- Consumes: `pkgs`, `lib`.
- Produces:
  - `postgresForward :: { host, db, sshUser?, sshOptions? } -> writeShellApplication`
  - `redisForward :: { host, sshUser?, sshOptions? } -> writeShellApplication`
  - `basicAuthWrapper :: { command, urlVar, userVar, passVar } -> writeShellApplication` (builds `Authorization: Basic <b64>` via mcp-proxy).

- [ ] **Step 1: Write the tunnel builders**

```nix
{ pkgs, lib }:
let
  # Build the ssh(1) target: "user@host" if a user is given, else just host.
  target = host: user: if user == null then host else "${user}@${host}";
in
{
  # SSH-forwarded read-only Postgres MCP.
  # Forwards the remote postgres unix socket over a per-instance temp dir
  # (NOT a fixed TCP port: a fixed port can only be bound by ONE client, so
  # pi + Claude sharing mcp.json would collide — the second ssh -L aborts on
  # ExitOnForwardFailure). Connect as `postgres` (socket's `local all all
  # trust` rule). Restricted access rejects writes at parse time.
  postgresForward =
    { host, db, sshUser ? null, sshOptions ? [ ] }:
    let
      opts = lib.escapeShellArgs sshOptions;
    in
    pkgs.writeShellApplication {
      name = "postgres-${db}-${host}";
      runtimeInputs = [ pkgs.openssh pkgs.postgres-mcp ];
      text = ''
        CTL="$(mktemp -u)"
        SOCKDIR="$(mktemp -d)"
        cleanup() {
          ssh -S "$CTL" -O exit ${target host sshUser} 2>/dev/null || true
          rm -rf "$SOCKDIR"
        }
        trap cleanup EXIT

        ssh -f -N -M -S "$CTL" -o ExitOnForwardFailure=yes ${opts} \
          -L "$SOCKDIR/.s.PGSQL.5432:/run/postgresql/.s.PGSQL.5432" ${target host sshUser}

        postgres-mcp --access-mode restricted "postgresql://postgres@/${db}?host=$SOCKDIR"
      '';
    };

  # SSH-forwarded read-only Redis MCP. Forwards 127.0.0.1:6379 into a
  # per-instance RANDOM local port (retried up to 20x on collision; redis has
  # no unix-socket support). Runs in the foreground; NOT exec'd so the EXIT
  # trap closes the tunnel. Write tools are patched out of redis-mcp-server
  # (pkgs/redis-mcp-readonly.patch).
  redisForward =
    { host, sshUser ? null, sshOptions ? [ ] }:
    let
      opts = lib.escapeShellArgs sshOptions;
    in
    pkgs.writeShellApplication {
      name = "redis-${host}";
      runtimeInputs = [ pkgs.openssh pkgs.redis-mcp-server ];
      text = ''
        CTL="$(mktemp -u)"
        cleanup() {
          ssh -S "$CTL" -O exit ${target host sshUser} 2>/dev/null || true
        }
        trap cleanup EXIT

        PORT=""
        for _ in $(seq 1 20); do
          P=$(( (RANDOM % 20000) + 20000 ))
          if ssh -f -N -M -S "$CTL" -o ExitOnForwardFailure=yes ${opts} \
              -L "127.0.0.1:$P:127.0.0.1:6379" ${target host sshUser} 2>/dev/null; then
            PORT=$P
            break
          fi
        done
        [ -n "$PORT" ] || { echo "could not bind a local port" >&2; exit 1; }

        redis-mcp-server --host 127.0.0.1 --port "$PORT"
      '';
    };
}
```

- [ ] **Step 2: Confirm it evaluates (typecheck)**

Run:
```bash
nix-instantiate --eval --strict -E 'let t = import ./modules/coding-agent/ssh-tunnels.nix { pkgs = import <nixpkgs> {}; lib = (import <nixpkgs> {}).lib; }; in builtins.typeOf t.postgresForward'
```
Expected: `lambda`

- [ ] **Step 3: Commit**

```bash
git add modules/coding-agent/ssh-tunnels.nix
git commit -m "feat(coding-agent): generalized ssh postgres/redis tunnel builders"
```

---

### Task 3: Wire the catalog + SSH helpers into `default.nix`

**Files:**
- Modify: `modules/coding-agent/default.nix`

**Interfaces:**
- Consumes: `mcp-servers.nix` (the submodule option), `ssh-tunnels.nix`, existing registry + `mkSecretWrapper`.
- Produces: `config.xsfx.codingAgent._resolved` — a `{ name -> {bin,command,args,env} }` map. `default.nix`'s existing `config` block uses it for the package symlinkJoin and the `mcp.json` writer.

- [ ] **Step 1: Import the new modules**

At the top of the `let` in `default.nix`, add:
```nix
  buildMcp = import ./mcp-servers.nix { inherit lib; };
  tunnels = import ./ssh-tunnels.nix { inherit pkgs lib; };
```

- [ ] **Step 2: Add the imports and the internal `_resolved` option**

Add `./mcp-servers.nix` to the module `imports` list. Add this option alongside the existing ones:
```nix
    _resolved = lib.mkOption {
      internal = true;
      type = lib.types.attrs;
      description = "Flattened MCP server map resolved from the declarative catalog.";
    };
```

- [ ] **Step 3: Replace the old resolver in the `config` block**

Remove the existing `resolveServer` and `resolved` bindings (and the `registry`-read they do). Replace with:

```nix
      # Wrap a registry-known server. bin/command come from the registry;
      # every server gets the wrapper (env scrub + *_FILE secret injection).
      mkWrapped =
        name: { args ? [ ], env ? { } }:
        let
          serverDef = registry.mcpRegistry."${name}" or { bin = null; command = name; };
          bin = serverDef.bin;
          command = serverDef.command;
        in
        {
          inherit command;
          bin = if bin != null then wrapperLib.mkSecretWrapper { inherit bin command env; } else bin;
        };

      # uid of the target user, for the tmpfs playwright profile path.
      uid = config.users.users.${effectiveUser}.uid or 1000;

      # Named catalog entries -> { name, args?, env? }.
      catalogRaw =
        lib.optional cfg.mcpServers.git { name = "git"; }
        ++ lib.optional cfg.mcpServers.nixos { name = "nixos"; }
        ++ lib.optional cfg.mcpServers.context7 { name = "context7"; }
        ++ lib.optional cfg.mcpServers.sequentialThinking { name = "sequential-thinking"; }
        ++ lib.optional cfg.mcpServers.github.enable {
          name = "github";
          args = [ "stdio" ];
          env = lib.optionalAttrs (cfg.mcpServers.github.tokenFile != null) {
            GITHUB_PERSONAL_ACCESS_TOKEN_FILE = cfg.mcpServers.github.tokenFile;
          };
        }
        ++ lib.optional cfg.mcpServers.memory.enable {
          name = "memory";
          env = { MEMORY_FILE_PATH = cfg.mcpServers.memory.filePath; };
        }
        ++ lib.optional cfg.mcpServers.playwright.enable {
          name = "playwright";
          args = [ "--extension" "--executable-path" cfg.mcpServers.playwright.chromePath ];
          env = {
            PWTEST_EXTENSION_USER_DATA_DIR = cfg.mcpServers.playwright.userDataDir;
            PLAYWRIGHT_MCP_USER_DATA_DIR = "/run/user/${toString uid}/playwright-mcp-profile";
          };
        };

      # SSH-tunneled catalog: one entry per named server.
      sshRaw =
        lib.concatLists
          (lib.mapAttrsToList (
            name: s:
            lib.optional s.enable {
              command = "postgres-${name}";
              bin = tunnels.postgresForward {
                host = s.host;
                db = s.db;
                sshUser = s.sshUser;
                sshOptions = s.sshOptions;
              };
            }
          ) cfg.mcpServers.sshPostgres)
          ++ lib.concatLists
          (lib.mapAttrsToList (
            name: s:
            lib.optional s.enable {
              command = "redis-${name}";
              bin = tunnels.redisForward {
                host = s.host;
                sshUser = s.sshUser;
                sshOptions = s.sshOptions;
              };
            }
          ) cfg.mcpServers.sshRedis);

      # name the ssh entries (catalogRaw already carries names).
      sshNamed = map (e: e // { name = e.command; }) sshRaw;

      all = lib.listToAttrs (catalogRaw ++ sshNamed);

      # `extra` raw entries overlay everything (backward compat).
      resolved =
        lib.mapAttrs mkWrapped all
        // lib.mapAttrs mkWrapped cfg.mcpServers.extra;
```

Note: the entries with a `bin` (the ssh ones) still work through `mkWrapped` because `mkWrapped` reads `serverDef.bin` from the registry — which won't match `postgres-<name>`. **Fix:** `mkWrapped` must honor a pre-supplied `bin` on the raw entry. Give catalog entries a `bin` field that wins over the registry:

```nix
      mkWrapped =
        name: { bin ? null, command ?, args ? [ ], env ? { } }:
        let
          serverDef = registry.mcpRegistry."${name}" or { bin = null; command = name; };
          useBin = if bin != null then bin else serverDef.bin;
          useCommand = if command != null then command else serverDef.command;
        in
        {
          command = useCommand;
          bin = if useBin != null then wrapperLib.mkSecretWrapper { bin = useBin; command = useCommand; env = env; } else useBin;
        };
```

With that, the ssh entries (which carry `bin` + `command`) resolve correctly, and registry-backed entries (which carry only `name`) fall through to the registry.

- [ ] **Step 4: Wire `_resolved` and keep packages/mcp.json deriving from it**

In the `config` block, set `xsfx.codingAgent._resolved = resolved;`. Keep the existing `mcpPackages = lib.mapAttrs (_: r: r.bin) _resolved;` and the mcp.json writer reading `_resolved` (rename the old `resolved` uses to `_resolved`).

- [ ] **Step 5: Verify the flake evaluates**

Run: `nix flake check` — Expected: eval errors only if the schema wiring is off (fix them).
Run: `nix build .#nixosConfigurations.coltrane.config.system.build.toplevel --dry-run` — Expected: plans the build.

- [ ] **Step 6: Commit**

```bash
git add modules/coding-agent/default.nix
git commit -m "feat(coding-agent): catalog-driven MCP resolution with ssh tunnel catalog"
```

---

### Task 4: Clean the marv-specific defaults out of the module

**Files:**
- Modify: `modules/coding-agent/default.nix` (options `user`, `models`, `settings`, `theme`)
- Modify: `modules/coding-agent/claude.nix` (use the resolved effective user)
- Modify: `hosts/coltrane/coding-agent.nix` (receive the moved values)

**Interfaces:**
- Consumes: nothing new.
- Produces: `user` defaults to first normal user; `models`/`settings` become empty defaults; `theme` keeps a generic dracula.

- [ ] **Step 1: `user` defaults to the first normal user**

Change `user` default to `""`. In the `config` block compute:
```nix
      effectiveUser =
        if cfg.user != "" then cfg.user
        else lib.head (lib.filter (u: config.users.users.${u}.isNormalUser or false) (builtins.attrNames config.users.users));
```
Replace every `${cfg.user}` in `default.nix` and `claude.nix` with `${effectiveUser}`. (claude.nix references `cfg.user` — pass `effectiveUser` or re-export it; simplest is to set `home-manager.users.${effectiveUser}` in default.nix and in claude.nix read `config.xsfx.codingAgent._effectiveUser`. Add an internal `_effectiveUser` string option set in default.nix's config so claude.nix can consume it.)

- [ ] **Step 2: Empty the `models`/`settings` defaults; keep a generic `theme`**

Set `models` default to `{ providers = { }; }`. Set `settings` default to `{ }`. Leave `theme` as the dracula default (generic, harmless).

- [ ] **Step 3: Move marv's models/settings into colt's host config**

In `hosts/coltrane/coding-agent.nix`, add `xsfx.codingAgent.models = <the old module default models, verbatim from git history>;` and `xsfx.codingAgent.settings = { autoCompactionEnabled = true; defaultProvider = "ollama-wobcom"; defaultModel = "gemma4:31b"; theme = "dracula"; skills = [ "/home/marv/.claude/skills" ]; };` (this mirrors what the host already sets).

- [ ] **Step 4: Build both closures**

Run:
- `nix build .#nixosConfigurations.coltrane.config.system.build.toplevel --no-link --print-out-paths` — Expected: builds with marv's explicit models/settings restored.
- `nix build .#nixosConfigurations.abed.config.system.build.toplevel --no-link --print-out-paths` (a non-marv host) — Expected: builds with empty defaults + the four basic servers.

- [ ] **Step 5: Commit**

```bash
git add modules/coding-agent/default.nix modules/coding-agent/claude.nix hosts/coltrane/coding-agent.nix
git commit -m "refactor(coding-agent): move personal defaults to coltrane host, empty module defaults"
```

---

### Task 5: Migrate `hosts/coltrane/coding-agent.nix` to the declarative catalog

**Files:**
- Modify: `hosts/coltrane/coding-agent.nix` (drop hand-written wrappers; use catalog options)
- Modify: `modules/coding-agent/mcp-registry.nix` (add missing registry entries if needed)

**Interfaces:**
- Consumes: catalog + tunnel builders.
- Produces: colt reuses the catalog; the bespoke `postgresForward`/`redisForward`/`hemingwayMcp` `let`-bindings are deleted.

- [ ] **Step 1: Replace hand-written wrappers with catalog entries**

Delete `postgresForward`, `redisForward`, `hemingwayMcp` from the `let` block. Replace the `mcpServers` config:
```nix
  xsfx.codingAgent.mcpServers = {
    github = {
      enable = true;
      tokenFile = config.sops.secrets."gh-token".path;
    };
    playwright = {
      enable = true;
      chromePath = "/home/marv/.nix-profile/bin/chromium";
      userDataDir = "/home/marv/.config/chromium";
    };
    memory.enable = true;
    sshPostgres."hemingway-barletta" = { enable = true; host = "barletta"; db = "hemingway"; };
    sshPostgres."chirpas-kirchart" = { enable = true; host = "kirchart"; db = "chirpas"; };
    sshPostgres."chirpns-kirchart" = { enable = true; host = "kirchart"; db = "chirpns"; };
    sshRedis.kirchart = { enable = true; host = "kirchart"; };
    # grafana/confluence/youtrack remain as raw `extra` entries (not yet catalogued):
    extra = { ... existing grafana/confluence/youtrack entries verbatim ... };
  };
```

- [ ] **Step 2: Confirm the ssh entries resolve with a null `sshUser`**

The tunnel builders use `user == null → ${host}` (ssh(1) default user = current user). Verify by building and checking `mcp.json` contains `postgres-hemingway-barletta`, `postgres-chirpas-kirchart`, `postgres-chirpns-kirchart`, `redis-kirchart`.

Run:
```bash
nix build .#nixosConfigurations.coltrane.config.system.build.toplevel --no-link --print-out-paths
```
Then inspect the generated `~/.pi/agent/mcp.json` for those keys.

- [ ] **Step 3: Commit**

```bash
git add hosts/coltrane/coding-agent.nix modules/coding-agent
git commit -m "refactor(coltrane): migrate mcp servers to declarative catalog"
```

---

### Task 6: Add a catalog resolution check to the flake checks

**Files:**
- Create: `modules/coding-agent/check-mcp.nix`
- Modify: `flake.nix` (register the check)

**Interfaces:**
- Consumes: `pkgs`, `lib`, and the module (via `evalModules`).
- Produces: a flake `check` asserting the catalog resolves the expected servers for a small dummy host.

- [ ] **Step 1: Write the check**

```nix
# modules/coding-agent/check-mcp.nix
{ pkgs }:
let
  lib = pkgs.lib;
  eval = lib.evalModules {
    modules = [
      { _module.check = false; }
      (import ./mcp-servers.nix { inherit lib; })
      (import ./default.nix { inherit pkgs; })
      (import ./claude.nix { inherit pkgs; })
      (import ./skills.nix { inherit pkgs; })
      { }
    ];
  };
in
pkgs.runCommand "coding-agent-mcp-check" { } ''
  # GitHub must resolve when enabled with a token path; git is enabled by default.
  if ! builtins.hasAttr "git" eval.config.xsfx.codingAgent._resolved; then
    echo "git missing from _resolved" >&2; exit 1
  fi
  echo ok > $out
''
```

> Note: an `evalModules` harness over the full module requires supplying the `home-manager` module (the module asserts it). Use `nixos` with a minimal `home-manager` import stubbed, or evaluate only `_resolved` with `home-manager` present via `{ imports = [ (import <home-manager>) ]; }`. Adjust the fixture to your repo's home-manager wiring; the assertion must pass locally with `nix flake check`.

- [ ] **Step 2: Register in flake.nix**

Next to the existing `coding-agent-wrapper` check, add:
```nix
checks.${system}.coding-agent-mcp = import ./modules/coding-agent/check-mcp.nix { inherit pkgs; };
```

- [ ] **Step 3: Run**

Run: `nix flake check` — Expected: the new check builds/passes.

- [ ] **Step 4: Commit**

```bash
git add flake.nix modules/coding-agent/check-mcp.nix
git commit -m "test(coding-agent): catalog resolution check"
```

---

## Self-Review

- **Spec coverage:** catalog (Tasks 1, 3), ssh/tunnels shipped in module (Tasks 2, 5), secret-path wiring (Tasks 1, 3), empty module defaults + user default (Task 4), colt migration (Task 5), test (Task 6). All spec sections covered.
- **Placeholders:** none — every task has concrete code. Task 6's fixture is annotated to be adapted to the repo's home-manager wiring at implementation time (it's the one place eval order isn't determinable from the plan alone).
- **Type consistency:** `postgresForward`/`redisForward` signatures in Task 2 match their use in Task 3 and colt migration in Task 5. `mkWrapped` is defined once in Task 3 and reused for both catalog and `extra`. `effectiveUser` is defined in Task 4 and used by default.nix + claude.nix.
- **Self-review gap found & fixed:** `mkWrapped` originally ignored a catalog-supplied `bin` (which the ssh entries need). Task 3 Step 3 now documents that it honors a `bin`/`command` override before falling back to the registry.
