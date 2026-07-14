# Project Context: NixOS Configuration & Pi Agent

This repository contains the NixOS configuration for multiple hosts using the **Coltrane** (columnar Nix) pattern. It also defines a highly customized `pi` agent environment with various MCP servers and extensions.

## 🛠 Core Architecture

### NixOS Setup
- **Pattern**: Coltrane (Columnar Nix). Host configurations are isolated in `hosts/<hostname>/`.
- **Secrets**: Managed via `sops-nix`. All sensitive tokens and passwords must be declared in `hosts/<hostname>/secrets.nix` and stored in an encrypted `.yaml` file.
- **Channels / `pkgs.unstable`**: The system builds on **nixpkgs stable (26.05)**. `nixpkgs-unstable` is imported exactly **once**, centrally, inside `overlays/default.nix`, and exposed as the attribute **`pkgs.unstable`** (the same `packageOverrides` are applied to both channels, so custom packages resolve identically — `pkgs.foo` = stable, `pkgs.unstable.foo` = unstable). There is **no `pkgsUnstable` specialArg** — reach unstable packages via `pkgs.unstable.<name>` in any NixOS or home-manager module (home-manager uses `useGlobalPkgs = true`, so it shares the system's overlaid `pkgs`). This deliberately avoids the "1000 instances of nixpkgs" antipattern of scattering `import nixpkgs-unstable {…}` across modules. `import` (not `.legacyPackages`) is required so `allowUnfree` can be set. Convention in package lists: **bare name = `pkgs.unstable`** (via `with pkgs.unstable;`), **`pkgs.<name>` = stable pin**.
- **Pi Agent**: A reusable NixOS module at `modules/coding-agent/`, exported from the flake as `nixosModules.coding-agent` and configured via the `xsfx.codingAgent.*` option tree (enabled per-host, e.g. `hosts/coltrane/coding-agent.nix`). The module is intentionally `pkgs`-only so it stays portable; the pinned/unstable packages (`pi-coding-agent`, `agent-browser`, the `mcp-*` servers) are sourced from `nixpkgs-unstable` by `overlays/coding-agent.nix`, which all hosts apply via `modules/base`.

### Pi Agent Layout
- `modules/coding-agent/default.nix` — the NixOS module (`options.xsfx.codingAgent` + the `symlinkJoin` that bundles pi + extensions + MCP packages).
- `modules/coding-agent/build-extensions.nix` — hand-assembles the three pi extensions (permission-system, mcp-adapter, browser-tools) from npm tarballs; pinned lockfiles live in `modules/coding-agent/lockfiles/`.
- `modules/coding-agent/mcp-registry.nix` — maps a logical MCP name to `{ bin, command }` on `pkgs`.
- `modules/coding-agent/wrapper.nix` — `mkSecretWrapper`, the generic secret-injection wrapper (see Grafana below).
- `modules/coding-agent/skills.nix` — the shared ECC asset pack (skills/agents/commands/rules) flattened into `~/.claude/*`, read by both pi and Claude.
- `modules/coding-agent/plugins.nix` — shared source for upstream plugin packs (superpowers, ponytail), loaded as extensions by pi and plugins by Claude.
- `overlays/coding-agent.nix` — sources pi + MCP packages from `nixpkgs-unstable` and pins `pi` to a release. It is a **sibling** of `overlays/default.nix` (personal packages), not nested inside it. Both are applied side-by-side in `modules/base` (`nixpkgs.overlays = [ overlays.coding-agent overlays.default ]`); neither overlay imports the other. `overlays.coding-agent` is also exported for third-party consumers of `nixosModules.coding-agent`.
- `modules/coding-agent/check-wrapper.nix` — pure `runCommand` test for the secret wrapper, exposed as `checks.x86_64-linux.coding-agent-wrapper`.

### Pi Agent Extension Pattern
To add a new MCP server to the agent:
1. If the package is not already on `pkgs`, add it to `overlays/coding-agent.nix` (sourced from `nixpkgs-unstable`).
2. Register the logical name → `{ bin, command }` mapping in `modules/coding-agent/mcp-registry.nix`.
3. Enable the server per-host under `xsfx.codingAgent.mcpServers.<name>` (e.g. in `hosts/coltrane/coding-agent.nix`), supplying `args`/`env`. A bare `{ }` entry is enough for non-secret servers — the module resolves `bin`/`command` from the registry.
4. If the server needs secrets, put the sops `*_FILE` paths in `env`. Any env key ending in `_FILE` triggers the secret wrapper automatically (see Grafana below).

### Plugin packs (superpowers + ponytail)
Two upstream Claude-Code plugin packs: **obra/superpowers** (TDD/debugging/planning)
and **DietrichGebert/ponytail** (minimalism). Fetched once in `plugins.nix`,
shared by both agents via native loading (extensions for pi, plugins for Claude).
Bump: edit `rev`/`hash` in `plugins.nix` and `nixos-rebuild switch`.
Lifecycle: requires pi/Claude restart to take effect.

## ⚠️ Known Issues & Critical Workarounds

### Grafana MCP Authentication Bug
- **The Bug**: The upstream `mcp-grafana` binary ignores the `GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE` environment variable, resulting in `401 Unauthorized` errors.
- **The Fix**: The generic `mkSecretWrapper` (`modules/coding-agent/wrapper.nix`) wraps `mcp-grafana`. Using the standard `_FILE` convention, it cats each `*_FILE` env var (a sops-managed path supplied in `env`) into the real env var (suffix stripped: `GRAFANA_URL_FILE` → `GRAFANA_URL`) before `exec`. The module auto-wraps any server whose `env` contains a `*_FILE` key; the coltrane host configures this in `hosts/coltrane/coding-agent.nix`.
- **Security**: All Grafana MCP calls are locked to read-only mode using the `--disable-write` flag (passed via `args`).

### Playwright Extension Mode (driving the already-open Chromium)
- **Mechanism**: In `--extension` mode the server opens a CDP **relay** (`ws://…/extension/<uuid>`) and spawns a Chromium (via `--executable-path` + `PWTEST_EXTENSION_USER_DATA_DIR`) to open the extension's `connect.html`, which singleton-forwards into your **already-running** Chromium (Profile 1). The installed Playwright Extension then connects back to the relay and bridges the MCP server to your real, logged-in tab. Verified working via `pw:mcp:relay` debug lines: `CDP relay server started … Establishing extension connection … Extension connection established … Playwright MCP connected`.
- **⚠️ The `PLAYWRIGHT_MCP_ISOLATED` trap (0.0.69→0.0.76 regression, root-caused & fixed 2026-07-14)**: nixpkgs' `playwright-mcp` bin is a **wrapper** that runs `if [ -z "$PLAYWRIGHT_MCP_USER_DATA_DIR" ]; then export PLAYWRIGHT_MCP_ISOLATED=1; fi`. Since 0.0.76 (playwright-core **1.61**) the browser-mode decision chain evaluates `isolated` **before** `extension` (`remoteEndpoint → cdpEndpoint → isolated → extension → persistent`), so that forced `ISOLATED=1` silently **wins over `--extension`** and launches a throwaway temp-profile browser (`/tmp/playwright_chromiumdev_profile-* --disable-extensions`, no logins) — the "opens a new browser" symptom. 0.0.69 evaluated extension first, so it was latent. **Fix**: set `PLAYWRIGHT_MCP_USER_DATA_DIR` in the server `env` so the wrapper skips the `ISOLATED=1` export. The value is *inert* in extension mode (the target is your running browser via the extension; nothing is stored there) — it points at the tmpfs `/run/user/<uid>/playwright-mcp-profile` purely as a sentinel, ephemeral if a fallback persistent launch ever fires. NB: `PLAYWRIGHT_MCP_ISOLATED=0` alone does **not** work — the wrapper re-forces it to `1` because it only checks `-z USER_DATA_DIR`. The relevant `--executable-path`/connect-page bug ([playwright#40557](https://github.com/microsoft/playwright/issues/40557)) was already fixed in 0.0.73, so that flag is honored — it was not the cause here.
- **All MCPs (incl. playwright-mcp) track `nixpkgs-unstable`** via `overlays/coding-agent.nix` (the `inherit (unstable) …` block); only `pi-coding-agent` is version-pinned. So a `flake update` can bump playwright-mcp and reintroduce version-specific behavior changes — re-check extension mode after a bump.
- **Extension install**: The Playwright Extension (Web Store id `mmlmfjhmonkocbjadbfplnigmagldckm`, currently v0.2.1) must be installed **manually from the Chrome Web Store in the active profile** (here `Profile 1`, not `Default`). `home-manager/modules/chromium.nix` declares it, but HM's `programs.chromium.extensions` only seeds a **fresh** profile — on the pre-existing profile it never installed, so install it once by hand.
- **Approval / token**: `--extension` uses **manual approval** — the connect page opens in your running Chromium once per session; no `PLAYWRIGHT_MCP_EXTENSION_TOKEN` env is configured (a *wrong* token hard-errors, worse than none). Set a token only to skip repeated approvals.
- **Lifecycle**: A killed `playwright-mcp` server is **not** auto-respawned by pi's MCP reconnect (it only refreshes cached tool metadata). To apply changed args/env, `sudo nixos-rebuild switch` (which regenerates `~/.pi/agent/mcp.json`) and **restart pi** so the server respawns from the new manifest.

### Local ollama (SYCL on the Intel Arc iGPU)
The local ollama is a hand-built SYCL container (`hosts/coltrane/ollama.nix`) driving the **Intel Arc 140V iGPU** (Lunar Lake) via Level Zero — there is no discrete GPU. Hard-won facts:

- **Shared memory, gated by *free* RAM.** The iGPU has no VRAM; it carves from the 30 GiB system DDR5. Its offload budget is decided **at model load time** from *genuinely-free* RAM (`MemFree`), **not** Linux "available" (which counts reclaimable cache the driver won't touch). During normal desktop use free RAM is ~3–7 GiB.
- **Flash attention is the lever that makes a 12B fit.** `OLLAMA_FLASH_ATTENTION=1` drops gemma4:12b's full-offload requirement from ~9.9 GiB to ~8.5 GiB (removes the V-cache padding a non-FA load adds) and, given enough free RAM, gets **49/49 layers = 100% GPU**. Verified safe on this SYCL build — output is valid. Without it, or under RAM pressure, the model partially spills to CPU (the "why is it on CPU" symptom — it's circumstantial, not a hard limit).
- **Context is a server env, not a client setting.** pi talks to ollama over the OpenAI-compat `/v1` endpoint, which has **no `num_ctx` field**, so pi's `contextWindow` is only pi's own prompt budget — it is *not* sent to the server. The real window is `OLLAMA_CONTEXT_LENGTH` in `ollama.nix` (pinned to 32768); keep pi's `contextWindow` equal to it or pi over-packs and the server silently truncates (`n_keep=4`).
- **`gemma4:*` are reasoning models.** Modelfile has `RENDERER gemma4` + `PARSER gemma4` and a thinking channel; a too-small `num_predict` returns **empty `content`** because generation ends while still in the thinking channel (not a bug). pi's model entry must set `reasoning = true`. For fast interactive local use, send `think:false`.
- **`nixos-rebuild switch` *does* auto-restart the `systemd.user` ollama service here** (the container is recreated with new `-e` env). No manual `systemctl --user restart` needed — contrary to the usual user-service caveat.

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
- `playwright`: Drives already-open Chromium tabs via the Playwright browser extension (extension mode). Requires `--executable-path` + `PWTEST_EXTENSION_USER_DATA_DIR` **and** `PLAYWRIGHT_MCP_USER_DATA_DIR` (see the **Playwright Extension Mode** section — the last one defeats the nixpkgs wrapper's forced `PLAYWRIGHT_MCP_ISOLATED=1`, which otherwise silently disables extension mode on 0.0.76+).
- `memory`: Persistent knowledge-graph memory at `~/.pi/agent/memory.jsonl`.

## 📝 Guidelines for the Agent
1. **Secret Handling**: NEVER hardcode secrets. Always use the `sops-nix` pattern.
2. **Grafana MCP**: the `grafana` MCP is locked read-only (`--disable-write`); use it for telemetry/log queries. Its URL and token come from sops secrets, not this file.
3. **Persistence**: Update this `CLAUDE.md` file whenever a significant architectural decision is made, a new workaround is discovered, or system changes are implemented.
4. **End-of-Session Update**: At the end of every session where changes are made, the agent MUST summarize the work and update `CLAUDE.md` to keep the project memory current.
