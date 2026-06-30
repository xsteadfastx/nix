# Project Context: NixOS Configuration & Pi Agent

This repository contains the NixOS configuration for multiple hosts using the **Coltrane** (columnar Nix) pattern. It also defines a highly customized `pi` agent environment with various MCP servers and extensions.

## 🛠 Core Architecture

### NixOS Setup
- **Pattern**: Coltrane (Columnar Nix). Host configurations are isolated in `hosts/<hostname>/`.
- **Secrets**: Managed via `sops-nix`. All sensitive tokens and passwords must be declared in `hosts/<hostname>/secrets.nix` and stored in an encrypted `.yaml` file.
- **Pi Agent**: A reusable NixOS module at `modules/coding-agent/`, exported from the flake as `nixosModules.coding-agent` and configured via the `xsfx.codingAgent.*` option tree (enabled per-host, e.g. `hosts/coltrane/coding-agent.nix`). The module is intentionally `pkgs`-only so it stays portable; the pinned/unstable packages (`pi-coding-agent`, `agent-browser`, the `mcp-*` servers) are sourced from `nixpkgs-unstable` by `overlays/coding-agent.nix`, which all hosts apply via `modules/base`.

### Pi Agent Layout
- `modules/coding-agent/default.nix` — the NixOS module (`options.xsfx.codingAgent` + the `symlinkJoin` that bundles pi + extensions + MCP packages).
- `modules/coding-agent/build-extensions.nix` — hand-assembles the three pi extensions (permission-system, mcp-adapter, browser-tools) from npm tarballs; pinned lockfiles live in `modules/coding-agent/lockfiles/`.
- `modules/coding-agent/mcp-registry.nix` — maps a logical MCP name to `{ bin, command }` on `pkgs`.
- `modules/coding-agent/wrapper.nix` — `mkSecretWrapper`, the generic secret-injection wrapper (see Grafana below).
- `overlays/coding-agent.nix` — sources pi + MCP packages from `nixpkgs-unstable` and pins `pi` to a release; composed by `overlays/default.nix`.
- `modules/coding-agent/check-wrapper.nix` — pure `runCommand` test for the secret wrapper, exposed as `checks.x86_64-linux.coding-agent-wrapper`.

### Pi Agent Extension Pattern
To add a new MCP server to the agent:
1. If the package is not already on `pkgs`, add it to `overlays/coding-agent.nix` (sourced from `nixpkgs-unstable`).
2. Register the logical name → `{ bin, command }` mapping in `modules/coding-agent/mcp-registry.nix`.
3. Enable the server per-host under `xsfx.codingAgent.mcpServers.<name>` (e.g. in `hosts/coltrane/coding-agent.nix`), supplying `args`/`env`. A bare `{ }` entry is enough for non-secret servers — the module resolves `bin`/`command` from the registry.
4. If the server needs secrets, put the sops `*_FILE` paths in `env`. Any env key ending in `_FILE` triggers the secret wrapper automatically (see Grafana below).

## ⚠️ Known Issues & Critical Workarounds

### Grafana MCP Authentication Bug
- **The Bug**: The upstream `mcp-grafana` binary ignores the `GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE` environment variable, resulting in `401 Unauthorized` errors.
- **The Fix**: The generic `mkSecretWrapper` (`modules/coding-agent/wrapper.nix`) wraps `mcp-grafana`. Using the standard `_FILE` convention, it cats each `*_FILE` env var (a sops-managed path supplied in `env`) into the real env var (suffix stripped: `GRAFANA_URL_FILE` → `GRAFANA_URL`) before `exec`. The module auto-wraps any server whose `env` contains a `*_FILE` key; the coltrane host configures this in `hosts/coltrane/coding-agent.nix`.
- **Security**: All Grafana MCP calls are locked to read-only mode using the `--disable-write` flag (passed via `args`).

### Playwright Extension Mode (driving the already-open Chromium)
- **Mechanism**: In `--extension` mode the server does **not** attach to your browser directly — it launches a Chromium to host the `chrome-extension://…/connect.html` approval page, and the installed extension then bridges the MCP server to the chosen tab.
- **The trap**: by default it launches Playwright's **bundled** chromium with a **temp profile** that has no Playwright Extension installed, so the connect page is blocked (`ERR_BLOCKED_BY_CLIENT`) and `browser_navigate` times out.
- **The fix** (configured in `hosts/coltrane/coding-agent.nix`): pass `--executable-path /home/marv/.nix-profile/bin/chromium` and set env `PWTEST_EXTENSION_USER_DATA_DIR=/home/marv/.config/chromium`. The spawned system-chromium then **singleton-forwards** the connect page into the already-running instance (your logged-in sessions) instead of opening a fresh browser. (`PWTEST_EXTENSION_USER_DATA_DIR` is the only knob extension mode reads for the profile dir — it's an internal `PWTEST_`-prefixed env var, so re-check it after a `playwright-mcp` bump.)
- **Extension install**: The Playwright Extension (Web Store id `mmlmfjhmonkocbjadbfplnigmagldckm`) must be installed **manually from the Chrome Web Store in the active profile** (here `Profile 1`, not `Default`). `home-manager/modules/chromium.nix` declares it, but HM's `programs.chromium.extensions` only seeds a **fresh** profile — on the pre-existing profile it never installed, so install it once by hand.
- **Approval / token**: `--extension` has **no "accept all tokens" mode** — the extension does a strict equality check against a per-profile token (`PLAYWRIGHT_MCP_EXTENSION_TOKEN`). We use **manual approval** (one click on the connect page per session); no token env is configured. Sending a *wrong* token hard-errors, worse than sending none.
- **Lifecycle**: A killed `playwright-mcp` server is **not** auto-respawned by pi's MCP reconnect (it only refreshes cached tool metadata). To apply changed args/env, `sudo nixos-rebuild switch` (which regenerates `~/.pi/agent/mcp.json`) and **restart pi** so the server respawns from the new manifest.

## 🗺 Hosts

The hosts defined in this repo (`hosts/`):

- `abed`
- `coltrane` — runs the pi agent and its MCP servers (configured in `hosts/coltrane/coding-agent.nix`), including the read-only Grafana MCP.
- `dipper`
- `phil`
- `troy`

> Note: any telemetry/hosts referenced by the Grafana MCP live outside this repo (the MCP's URL/token are sops secrets, not stored here).

## ⚙️ Operational Guide

### Basic Commands
- **Rebuild & Switch**: `sudo nixos-rebuild switch`
- **Verify Flake**: `nix flake check`
- **Build a host's system closure (no sudo needed)**: `marv` is in `trusted-users`, so build the toplevel directly instead of `nixos-rebuild` (which needs a sudo password / TTY): `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link --print-out-paths` (e.g. `.#coltrane`). This validates eval + builds the full closure (and home-manager generation) without switching. Add `--dry-run` to just check eval + plan.
- **Format before committing**: Run `nix fmt` before any commit. The pre-commit hook runs `nixfmt` and will reject (and reformat) staged `.nix` files; formatting up front avoids the abort-re-stage loop. Note: the hook fails the commit if any staged file is also dirty with unstaged changes, so format and stage the whole file before committing.

### Tooling Checklist
The agent has the following MCPs configured:
- `nixos`: For NixOS/Home Manager queries.
- `git`: For local repository operations.
- `grafana`: (Wrapped) For telemetry and logs.
- `context7`: For up-to-date library documentation.
- `sequential-thinking`: For structured problem-solving.
- `playwright`: Drives already-open Chromium tabs via the Playwright browser extension (extension mode). See the **Playwright Extension Mode** section below for the required `--executable-path` + `PWTEST_EXTENSION_USER_DATA_DIR` config and the manual-approval flow — it is **not** a bare `--extension` setup.
- `memory`: Persistent knowledge-graph memory at `~/.pi/agent/memory.jsonl`.

## 📝 Guidelines for the Agent
1. **Secret Handling**: NEVER hardcode secrets. Always use the `sops-nix` pattern.
2. **Grafana MCP**: the `grafana` MCP is locked read-only (`--disable-write`); use it for telemetry/log queries. Its URL and token come from sops secrets, not this file.
3. **Persistence**: Update this `CLAUDE.md` file whenever a significant architectural decision is made, a new workaround is discovered, or system changes are implemented.
4. **End-of-Session Update**: At the end of every session where changes are made, the agent MUST summarize the work and update `CLAUDE.md` to keep the project memory current.
