# Agent Instructions for NixOS Configuration Repository

## Repository Overview

This repository contains a NixOS configuration using the **coltrane** (columnar Nix) pattern. Host‑specific configurations live under `hosts/<hostname>/`. The main entry point for the system is `flake.nix`. The repository also ships a collection of custom Nix packages under `pkgs/` and reusable modules under `modules/`.

## Essential Commands

| Action | Command | Description |
|--------|---------|-------------|
| Rebuild & switch system | `sudo nixos-rebuild switch` | Apply the current configuration and reboot if needed |
| Test rebuild (no reboot) | `sudo nixos-rebuild test` | Validate the configuration without switching |
| Build for deployment | `sudo nixos-rebuild build` | Produce a Nix store closure for remote deployment |
| Verify flake validity | `nix flake check` | Lint the flake and run any defined checks |
| Garbage‑collect unused store paths | `sudo nix-collect-garbage -d` | Clean the Nix store |
| Enter a development shell | `nix develop` (if `devShells` are defined) | Open an environment with project dependencies |

## Code Organization & Architecture

- **`flake.nix`** – Top‑level flake definition. Declares inputs, outputs, and the `nixosConfigurations` attribute.
- **`hosts/`** – One directory per machine. Each contains:
  - `configuration.nix` – Host‑specific system configuration.
  - `crush.nix` – Crush (AI assistant) configuration, including provider definitions and LSP settings.
  - Additional service modules (e.g., `ollama.nix`, `paperless.nix`).
- **`modules/`** – Reusable Nix modules that can be imported by any host configuration.
- **`pkgs/`** – Custom Nix packages built from source (Go, Rust, Python, etc.).
- **`home-manager/`** – Per‑user Home Manager configuration (`marv.nix`).
- **`overlays/`** – Nixpkgs overlays providing extra packages or overrides.

### Columnar Nix (Coltrane) Pattern

The `crush.nix` file builds a JSON configuration using `builtins.toJSON`. This JSON is then written to `~/.config/crush/crush.json` via Home Manager. The pattern allows declarative definition of:
- **Providers** (local and remote Ollama instances) with model lists.
- **LSP settings** for Go (`gopls`) and Nix (`nil`).
- **Options** such as `context_paths`, UI mode, and debug flag.

## Naming Conventions & Style

- Host directories: lower‑case hostnames (`coltrane`, `abed`, …).
- Provider IDs: kebab‑case (`ollama-local`).
- Model IDs: match Ollama naming, may include version suffixes (`qwen2.5-coder:14b`).
- Nix attributes follow standard Nix style (snake_case, lower‑case). Files use `.nix` extension.

## Testing & CI

- **GitHub Actions** (if present) run `nix flake check` on each push.
- Unit‑style checks are performed by the flake’s `checks` attribute; they typically run `nix build` on individual derivations.
- System validation: `nixos-rebuild test` ensures the config can be built on the target hardware.

## Important Gotchas

1. **Nix evaluation order** – Circular attribute references will cause infinite loops. Use `lib.mkIf` or lazy attributes when necessary.
2. **Attribute set merging** – When extending a module, prefer `lib.recursiveUpdate` to preserve nested fields.
3. **Flake input pins** – Updating inputs (e.g., `nixpkgs`) requires `nix flake update` and a full rebuild.
4. **Store path handling** – Always refer to full store paths (`/nix/store/...`) or the `result` symlink; shortened paths are unreliable.
5. **Garbage collection** – Running `nix-collect-garbage -d` can remove devShell outputs if not referenced elsewhere.
6. **Crush JSON generation** – The `crushConfig` JSON is regenerated on each `nixos-rebuild`; manual edits to `~/.config/crush/crush.json` will be overwritten.
7. **Model context windows** – Some models (e.g., `qwen2.5-coder`) have large context windows; ensure prompts stay within limits to avoid truncation.
8. **Home Manager ordering** – The `force = true` flag in `home-manager.users.marv.xdg.configFile` ensures the generated `crush.json` overwrites any existing file.

## Debugging Tips

- **Crush logs**: `crush logs` or view `~/.config/crush/logs`.
- **LSP diagnostics**: `crush lsp diagnostics` to see errors in `crush.nix`.
- **Nix rebuild logs**: `journalctl -u nixos-rebuild.service` (if using a systemd unit) or watch the console output of `nixos-rebuild`.
- **Flake checks**: Run `nix flake check` locally to reproduce CI failures.

## Resources

- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **Coltrane documentation** – see comments in `hosts/coltrane/crush.nix`.
- **Ollama model list**: https://ollama.com/library
- **Home Manager**: https://nix-community.github.io/home-manager/

*Keep this file up to date when adding new hosts, modules, or custom packages.*