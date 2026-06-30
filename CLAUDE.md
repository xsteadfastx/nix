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

## 🗺 Infrastructure Map

### Telemetry & Monitoring
- **Grafana URL**: `https://viz.smartmetering.service.wobcom.de`
- **Loki/Logs**: Centralized logging.
- **Key Hosts**:
    - `hawk`: Central monitoring and Loki host.
    - `templeton`: Host for the `hemingway-eventlistener` and related telemetry services.

### Service Stack (Hemingway)
- **Event Listener**: `hemingway-eventlistener.service` (processes uplink events).
- **Pusher Services**: `hemingway-pusher-db.service` and `hemingway-pusher-kvasy.service`.
- **Locator Service**: `hemingway-locator.service`.

## ⚙️ Operational Guide

### Basic Commands
- **Rebuild & Switch**: `sudo nixos-rebuild switch`
- **Verify Flake**: `nix flake check`
- **Format before committing**: Run `nix fmt` before any commit. The pre-commit hook runs `nixfmt` and will reject (and reformat) staged `.nix` files; formatting up front avoids the abort-re-stage loop. Note: the hook fails the commit if any staged file is also dirty with unstaged changes, so format and stage the whole file before committing.

### Tooling Checklist
The agent has the following MCPs configured:
- `nixos`: For NixOS/Home Manager queries.
- `git`: For local repository operations.
- `grafana`: (Wrapped) For telemetry and logs.
- `context7`: For up-to-date library documentation.
- `sequential-thinking`: For structured problem-solving.

## 📝 Guidelines for the Agent
1. **Secret Handling**: NEVER hardcode secrets. Always use the `sops-nix` pattern.
2. **Verification**: Before assuming a service is "down," check the Loki logs via the Grafana MCP using `{instance="<hostname>"}`.
3. **Persistence**: Update this `CLAUDE.md` file whenever a significant architectural decision is made, a new workaround is discovered, or system changes are implemented.
4. **End-of-Session Update**: At the end of every session where changes are made, the agent MUST summarize the work and update `CLAUDE.md` to keep the project memory current.
