# Agent Instructions for NixOS Configuration Repository

## Repository Overview

This repository contains a multi-host NixOS configuration using the **coltrane** (columnar Nix) pattern. Host‑specific configurations live under `hosts/<hostname>/`. The main entry point is `flake.nix`. Reusable modules sit in `modules/`, custom packages in `pkgs/`, and per-user Home Manager config in `home-manager/m arv.nix`.

## Essential Commands

| Action | Command | Description |
|--------|---------|-------------|
| Rebuild & switch system | `sudo nixos-rebuild switch` | Apply the current configuration and reboot if needed |
| Test rebuild (no reboot) | `sudo nixos-rebuild test` | Validate the configuration without switching |
| Verify flake validity | `nix flake check` | Lint the flake and run any defined checks |
| Garbage‑collect unused store paths | `sudo nix-collect-garbage -d` | Clean the Nix store |
| Enter a development shell | `nix develop` (if `devShells` are defined) | Open an environment with project dependencies |

## Code Organization & Architecture

- **`flake.nix`** – Top‑level flake definition. Declares inputs, outputs, and the `nixosConfigurations` attribute.
- **`hosts/`** – One directory per machine (`coltrane`, `abed`, `dipper`, `phil`, `troy`). Each host is self-contained: its own `configuration.nix`, `hardware-configuration.nix`, service modules, and `secrets.nix`. No cross-host imports.
- **`modules/`** – Reusable NixOS and Home Manager modules shared across hosts (e.g., `base/`, `coding-agent/`).
- **`overlays/`** – Nixpkgs overlays (`default.nix` for personal packages, `coding-agent.nix` sourcing pi/MCP from unstable).
- **`home-manager/m arv.nix`** – Per-user Home Manager configuration.

### Columnar Nix (Coltrane) Pattern

Each host lives in its own directory under `hosts/`. Host configs import the shared modules they need and declare their own secrets — nothing leaks between hosts, and adding a new machine is just a new directory plus a one-line entry in `flake.nix`. The pattern keeps per-host complexity isolated while letting modules compose.

## Naming Conventions & Style

- Host directories: lower‑case hostnames (`coltrane`, `abed`, …).
- Provider IDs (Ollama, Grafana, etc.): kebab‑case.
- Nix attributes follow standard Nix style (snake_case, lower‑case). Files use `.nix` extension.

## Testing & CI

- **GitHub Actions** (if present) run `nix flake check` on each push.
- Unit‑style checks are performed by the flake's `checks` attribute; they typically run `nix build` on individual derivations.
- System validation: `nixos-rebuild test` ensures the config can be built on the target hardware.

## Important Gotchas

1. **Nix evaluation order** – Circular attribute references will cause infinite loops. Use `lib.mkIf` or lazy attributes when necessary.
2. **Attribute set merging** – When extending a module, prefer `lib.recursiveUpdate` to preserve nested fields.
3. **Flake input pins** – Updating inputs (e.g., `nixpkgs`) requires `nix flake update` and a full rebuild.
4. **Store path handling** – Always refer to full store paths (`/nix/store/...`) or the `result` symlink; shortened paths are unreliable.
5. **Garbage collection** – Running `nix-collect-garbage -d` can remove devShell outputs if not referenced elsewhere.
6. **Secrets via sops-nix** – All sensitive tokens and passwords must be declared in each host's `secrets.nix` and stored encrypted as `.yaml`. Never hardcode secrets.
7. **Grafana MCP auth bug** – The upstream binary ignores `GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE`; the module wraps it with `mkSecretWrapper` to cat `_FILE` env vars into real names before exec. Any host config adding a `*_FILE` key triggers this automatically.
8. **Home Manager ordering** – Some XDG files use `force = true` to overwrite existing configs; check before assuming stale state is intentional.

## Debugging Tips

- **Nix rebuild logs**: `journalctl -u nixos-rebuild.service` (if using a systemd unit) or watch the console output of `nixos-rebuild`.
- **Flake checks**: Run `nix flake check` locally to reproduce CI failures.
- **SOPS secrets**: `sops file hosts/<host>/secrets.yaml` to inspect encrypted values; `sops file --decrypt …` to read raw.

## Resources

- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **Ollama model list**: https://ollama.com/library
- **Home Manager**: https://nix-community.github.io/home-manager/

*Keep this file up to date when adding new hosts, modules, or custom packages.*
