# Design: Configurable, coworker-friendly `coding-agent` module

Date: 2026-08-20

## Goal

Make the pi coding-agent usable by coworkers. A host adopts the agent by setting a
few options — enable MCPs, attach secret file paths — with no knowledge of
wrappers, registries, or env-scrubbing. Everything marv-specific is pushed out of
the module defaults into `hosts/coltrane/`; the module ships generic, reusable
machinery.

The SSH-tunnel MCP wrappers (postgres/redis over SSH forwarding) are genuinely
useful against the company's infrastructure, so they ship in the module as
generic option-backed builders — not locked in coltrane's host config.

## Architecture

The module (`modules/coding-agent/`) keeps its existing core (registry, wrapper,
plugins, build-extensions) but exposes a declarative MCP catalog and cleans its
defaults.

### A. Declarative MCP catalog (`xsfx.codingAgent.mcpServers.*`)

Each known server becomes a sub-option with `enable` plus the fields it needs.
The module owns `bin`/`command`/wrapper construction via the existing registry +
`mkSecretWrapper`. Coworkers never touch wrappers.

| Server | Fields | Secret? |
|---|---|---|
| `git`, `nixos`, `context7`, `sequential-thinking` | — (bare) | no |
| `github` | `tokenFile` | yes |
| `playwright` | `chromePath`, `profile` | no |
| `memory` | `filePath` | no |
| `sshPostgres.<name>` | `host`, `db`, `sshUser`?, `sshOptions`? | no (ssh-key auth) |
| `sshRedis.<name>` | `host`, `sshUser`?, `sshOptions`? | no |
| `httpBasic.<name>` | `urlFile`, `usernameFile`, `passwordFile` | yes |
| `extra` | free-form raw (escape hatch) | any |

- `sshUser`/`sshOptions` default to empty, so a coworker whose username differs
  from the infra host's can set them. Each `sshPostgres.<name>`/`sshRedis.<name>`
  names its own SSH target host and DB.
- Backward compatibility: the raw option shape (the current `bin`/`command`/`args`
  /`env` entries) is preserved via `mcpServers.extra` and by tolerating raw
  entries under any catalog name.

### B. Automatic secret wiring

`tokenFile`/`usernameFile`/`passwordFile`/etc. feed the existing
`*_FILE` → `mkSecretWrapper` mechanism. Coworker sets a path; the module builds
the wrapper. Secrets are never stored in the module — only file paths, which
coworkers source from their own `config.sops.secrets."<name>".path`.

### C. Defaults

- `user` defaults to the first normal user (no hardcoded `marv`).
- Non-secret, hardware-agnostic servers (`git`, `nixos`, `context7`,
  `sequential-thinking`) enabled on `enable = true`; everything secret-bound is
  opt-in.
- `models`/`theme`/`settings` defaults become minimal/generic; coltrane's full
  values move into `hosts/coltrane/coding-agent.nix` as explicit config.

### D. Coltrane migration

`hosts/coltrane/coding-agent.nix` switches to the declarative options
(`sshPostgres`, `sshRedis`, `httpBasic`) and drops its hand-written
`postgresForward`/`redisForward`/`hemingwayMcp` wrapper `let`-bindings. marv's
models/theme/settings move from module defaults into coltrane config.

### E. Packaging

Stays in this repo as a cleanly-optioned module. No new flake (YAGNI). If
coworkers later need a standalone repo, that's a separate extraction effort.

## Out of scope (YAGNI)

- Standalone flake/repo packaging.
- Central secret store — secrets stay per-host in sops.
- New MCP server implementations beyond the catalog above.

## Error handling

- Assertions: an enabled catalog server that is missing a required secret field
  (e.g. `github` with no `tokenFile`) fails eval with a clear message.
- `sshPostgres`/`sshRedis` keep the existing per-instance tunnel + trap pattern
  (no fixed ports, exit cleanup).
