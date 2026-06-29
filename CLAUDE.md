# Project Context: NixOS Configuration & Pi Agent

This repository contains the NixOS configuration for multiple hosts using the **Coltrane** (columnar Nix) pattern. It also defines a highly customized `pi` agent environment with various MCP servers and extensions.

## 🛠 Core Architecture

### NixOS Setup
- **Pattern**: Coltrane (Columnar Nix). Host configurations are isolated in `hosts/<hostname>/`.
- **Secrets**: Managed via `sops-nix`. All sensitive tokens and passwords must be declared in `hosts/<hostname>/secrets.nix` and stored in an encrypted `.yaml` file.
- **Pi Agent**: Integrated as a system package. Extensions and MCP servers are bundled via a `symlinkJoin` in `hosts/coltrane/pi/default.nix`.

### Pi Agent Extension Pattern
To add a new tool or MCP server to the `pi` agent:
1. Add the package to the `paths` list in `piWithExtensions` within `hosts/coltrane/pi/default.nix`.
2. Configure the server in the `mcpServers` block of the `mcp.json` generated for the agent.
3. If the tool requires secrets, use a wrapper script (`pkgs.writeShellScriptBin`) to inject secrets from sops-managed files into the environment variables.

## ⚠️ Known Issues & Critical Workarounds

### Grafana MCP Authentication Bug
- **The Bug**: The upstream `mcp-grafana` binary ignores the `GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE` environment variable, resulting in `401 Unauthorized` errors.
- **The Fix**: A wrapper derivation `mcpGrafanaWrapped` is used. It reads the token and URL from the filesystem (provided by sops-nix) and exports them as direct environment variables (`GRAFANA_SERVICE_ACCOUNT_TOKEN` and `GRAFANA_URL`) before executing the binary.
- **Security**: All Grafana MCP calls are locked to read-only mode using the `--disable-write` flag.

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
