# Fish → Home-Manager Native Conversion Design

**Status:** approved-in-principle, pending user spec review
**Date:** 2026-09-18
**Author:** marv + agent

## Goal

Replace the hand-rolled fish config at `home-manager/modules/fish/` — which
presently **copies a raw tree** of `.fish` scripts into `~/.config/fish` via
`xdg.configFile."fish" = { source = ./fish; recursive = true; }` — with the
native Home-Manager **`programs.fish`** module options (`shellAbbrs`,
`shellAliases`, `functions`, `shellInit`, `interactiveShellInit`,
`promptInit`, …), moving env vars to `home.sessionVariables` and static PATH
dirs to `home.sessionPath`. The whole thing is **port + trim**, and keeps all
live behavior identical (notably ssh-agent + gopass key loading).

## Target structure

- **Rewrite** `home-manager/modules/fish/default.nix` into a single
  `programs.fish`-driven file. It also enables `programs.starship` (native).
- **Delete** the raw `fish/` directory (`config.fish`, `conf.d/`,
  `functions/`, `completions/`) and the whole-dir `xdg.configFile."fish"`.

## Mapping (`fish/` → native options)

### Env vars → `home.sessionVariables`
| raw fish | value |
|---|---|
| `set -gx EDITOR` | `nvim` |
| `set -gx GOPATH` | `$HOME/.local/share/go` |
| `set -gx BAT_THEME` | `Dracula` |
| `set -gx FZF_DEFAULT_OPTS` | existing multi-line string |

### PATH → `home.sessionPath` (static dirs) + `fish_add_path` (dynamic)
- `home.sessionPath`: `~/bin`, `~/.local/bin`, `~/.local/share/go/bin`
- dynamic, in `programs.fish.shellInit` via `fish_add_path`:
  - `~/bin/(uname -m)`, `~/bin/(hostname)` — command substitution, can't be
    declarative
- conditional guarded blocks (kept, in `interactiveShellInit`, using
  `fish_add_path` instead of mutating `fish_user_paths`):
  `/sbin`, `~/.poetry/bin`, `~/.krew/bin`, linuxbrew, asdf, `/usr/pgadmin4`,
  `~/library/apps/git-fuzzy`

### Abbreviations → `programs.fish.shellAbbrs`
All ~35 `abbr -a` entries ported verbatim as strings: git (`g ga gc gco gd
gu gs gp gt gw`), ls (`ll`), `cat`→`bat`, `vim`→`nvim`, `fd`, `rg`, `prev`,
`watch`→`viddy`, `k`, `ks`, `mutt`→`neomutt` (guarded), `rcp`, `rmv`, `tf`,
`t`, `ssh`, `yaegi`, `jellyfin-mpv`, radio abbrs (`coderadio`, `chillradio`,
`synthwaveradio`).

### Functions → `programs.fish.functions.*`
- `2mkv`, `2mkv265` (native one-file-per-function splits these — fixes the
  current autoload-only-first-func quirk), `2mp4`, `bkp_christine`,
  `dig_acme_xsfx`, `enter`, `git-clone-bare-for-worktrees`, `sudo` (`sudo
  !!`), `wip`
- moved out of `config.fish` into functions: `fish_greeting`,
  `fish_mode_prompt`, `fish_user_key_bindings`
- **kept** `fish_ssh_agent.fish` as `functions.fish_ssh_agent` (user vetoed
  its removal; agent matters)

### Interactive init → `programs.fish.interactiveShellInit`
- `fish_vi_key_bindings`
- `set default_user marv`
- gpg-agent guard block
- `gopass completion fish | source`
- guarded brew / asdf / grc wrapper-loop / krew / pgadmin4 / git-fuzzy blocks
- `direnv hook fish | source` (kept as one-liner; not enabling the full
  `programs.direnv` module)
- dracula color scheme (`conf.d/dracula.fish` body)
- **ssh-agent + gopass key load** (`conf.d/ssh-agent-prepare.fish` body) —
  the live agent handler, kept exactly. Starts agent, sets `SSH_AUTH_SOCK`,
  loops `gopass ls -f ssh/` → `gopass show -n $key | ssh-add -`.

### Prompt → `programs.fish.promptInit`
- `starship init fish | source` (with the original `TERM != dumb` guard)

### Starship → native `programs.starship`
- `programs.starship = { enable = true; package = pkgs.unstable.starship;
  enableFishIntegration = true; settings = { kubernetes.disabled = false; aws
  = { symbol = "…" }; … }; }` — the existing `starship.toml` symbol entries
  become `settings` attrs
- **remove** the current `xdg.configFile."starship.toml"` (module writes it)

### Shell init → `programs.fish.shellInit`
- dynamic `fish_add_path` lines above

## Deletions (dead / redundant)

- `grc.wrap.fish` (unused)
- `conf.d/nix.fish` + `source ~/.nix-profile/etc/profile.d/nix.fish` +
  `babelfish < hm-session-vars` (NixOS supplies nix env; HM sources session
  vars natively)
- `completions/gopass.fish` (redundant with `gopass completion fish | source`)
- `# FIXME: LC_ALL`, `set -e fish_user_paths`, `abbr --erase (abbr --list)`
  (obsolete under native ownership)

## Migration (post-switch, one-time, run by user)

```fish
abbr --erase (abbr --list)
set -e fish_user_paths
```
Clears old universal abbrs/paths so HM's generated definitions own them
cleanly. (HM sets abbrs per-shell in `config.fish`.)

## Not changed

- `home.packages` keeps `unstable.fish`, `starship`.
- Host-level `programs.fish.enable = true` in `configuration.nix` remains
  (that is the **NixOS** system fish module — shell registration +
  completions — and is orthogonal).

## Testing

1. `nix flake check` (runs pre-commit formatting/lint gate).
2. Post-rebuild verification:
   - `fish -c 'abbr --list | head'`
   - `fish -c 'set -q EDITOR; and echo ok'`
   - `which rg fd kitty` (PATH intact)
   - interactive run: vi mode, prompt, ssh-agent `~/.ssh` socket + `ssh-add
     -l` shows gopass keys.
