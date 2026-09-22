# Sway Migration — Implementation Plan (coltrane)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the i3/X11 session on coltrane with a Sway (Wayland) session, keeping i3 as an easily-selectable fallback in lightdm.

**Architecture:** Enable sway alongside the existing i3/lightdm stack (`programs.sway.enable`), set sway as the default lightdm session, and port the i3 home-manager module to sway. Sway's native IPC-compatible `workspace N output PORT` pinning replaces the bespoke i3-msg/xrandr multi-monitor automation in `autorandr.nix` and `lock.nix`, which are deleted/simplified accordingly. No compositor-level regression risk: sway keeps the `--no-dpms` behavior that preserves the xe/MST topology.

**Tech Stack:** NixOS, Home Manager, Sway (wlroots), swaylock, swayidle.

## Global Constraints

- Keep `services.xserver.windowManager.i3.enable = true` so i3 remains a lightdm fallback session.
- Commit to sway: the i3-specific automation (`autorandr.nix` hooks, `lock.nix` snapshot/replay) is replaced, not maintained in parallel. Revert = `git checkout` the relevant commits.
- Preserve the `--no-dpms` invariant from the old lock (original comment: DPMS killed the xe/MST topology).
- Preserve monitor geometry, workspace↔output policy, layout = `de`, option `caps:escape`, and the Dracula look.
- XWayland keeps dunst + rofi working initially. Migrating to mako/fuzzel is an explicit, out-of-scope follow-up.
- **No deploy by the agent.** The agent prepares builds; the user runs `nixos-rebuild switch` and the login session tests.

---

## Current state (confirmed on the live box)

- **DM:** lightdm (NixOS default from `services.xserver.enable = true`, no explicit DM config).
- **Session:** lightdm → `~/.xinitrc` (unmanaged $HOME dotfile) → `exec i3`. Plus `services.xserver.windowManager.i3.enable = true`.
- **Automation to replace:**
  - `hosts/coltrane/autorandr.nix` — 3 profiles (`mobile`, `home`, `work`) + `move-workspaces` hooks (i3-msg + xrandr).
  - `hosts/coltrane/lock.nix` — i3lock-color + xss-lock `--transfer-sleep-lock` + workspace snapshot/replay.
  - `hosts/coltrane/fix-isy-hub.nix` — ISY USB-C hub rebind (the real MST fix) + boot `autorandr --change`.
  - `home-manager/modules/i3/` — i3 config + `i3auto` + rofi + dunst.

## Key insight

Sway is i3-compatible IPC and has native `workspace N output PORT` pinning. That pinning (a) replaces all of `move-workspaces`, (b) auto-restores layout on re-dock, and (c) **destroys the entire workspace snapshot/replay machinery** in `lock.nix`. We go from ~250 lines of bespoke multi-monitor logic to a handful of sway config lines.

## Monitor facts (from `autorandr.nix` profiles)

| Profile | Outputs (L→R) |
|---------|---------------|
| mobile | eDP-1 `1920x1200@120` 0,0 |
| home | eDP-1 0,0 · DP-1-3 `1920x1080@60` 1920,0 · DP-1-4 `1360x768@60` 3840,0 |
| work | eDP-1 0,0 · DP-1 `1920x1080@60` 1920,0 · DP-2 `1920x1080@60` 3840,0 |

Sway ignores `output`/`workspace` blocks whose ports are absent → one static config covers all three profiles with no runtime profile switching.

## Workspace policy (preserved from `move-workspaces`)

`ws1 → middle ext` · `ws2 → eDP-1` · `ws3 → right ext` ⇒ `workspace 1 output DP-1-3 DP-1` / `workspace 2 output eDP-1` / `workspace 3 output DP-1-4 DP-2`.

---

### Task 1: Enable sway + default session (keep i3 as fallback)

**Files:**
- Modify: `hosts/coltrane/configuration.nix`

**Interfaces:**
- Consumes: nothing new.
- Produces: `programs.sway.enable` and defaultSession set; lightdm lists both `i3` and `sway` sessions.

After the i3 WM line (~139):
```nix
services.xserver.windowManager.i3.enable = true;   # keep — lightdm fallback session
programs.sway.enable = true;                        # registers sway session + sway-session target
services.displayManager.defaultSession = "sway";    # default boot session; i3 selectable in lightdm
```

Update the `earlyoom --avoid` regex so sway processes aren't killed:
```nix
"^(X|i3.*|sway.*|sshd|systemd|ghostty|alacritty|zellij)$"
```

- [ ] **Step 1:** Edit `hosts/coltrane/configuration.nix` as above.
- [ ] **Step 2:** `sudo nixos-rebuild build` — expected: build succeeds, exit 0.
- [ ] **Step 3:** Verify lightdm session dir will list both sessions (`services.displayManager.sessionPackages` now includes sway). Confirm `programs.sway.enable` does not change the chosen display manager (it shouldn't — lightdm stays).
- [ ] **Step 4:** Commit: `feat(coltrane): enable sway session alongside i3 for Wayland migration`.

### Task 2: Create `home-manager/modules/sway/` (mirror of i3)

**Files:**
- Create: `home-manager/modules/sway/default.nix`
- Modify: `home-manager/modules/x11.nix` (add `./sway` to imports)

**Interfaces:**
- Consumes: `nixosConfig.features.x11` gate (same pattern as `modules/i3`).
- Produces: sway config at `~/.config/sway/config`, a `sway-autostart` shell script, rofi + dunst configs (reused via XWayland).

Create `home-manager/modules/sway/default.nix` (full skeleton; port i3 bindsyms verbatim — see `home-manager/modules/i3/config` for the exact binding set and Dracula rofi/dunst configs to copy):

```nix
{ lib, nixosConfig, pkgs, ... }:
let
  cfg = nixosConfig.features;
in
lib.mkIf cfg.x11 {
  xdg.configFile."sway/config".source = ./config;

  home.packages = [
    pkgs.unstable.rofi
    (pkgs.writeShellScriptBin "sway-autostart" ''
      ${pkgs.dunst}/bin/dunst &
      ${pkgs.networkmanagerapplet}/bin/nm-applet &
      ${pkgs.blueman}/bin/blueman-applet &
      ${lib.optionalString nixosConfig.services.syncthing.enable ''
        ${pkgs.unstable.syncthingtray}/bin/syncthingtray --wait &
      ''}
      ${pkgs.flameshot}/bin/flameshot &
    '')
  ];

  # rofi + dunst configs: copy verbatim from home-manager/modules/i3/default.nix
  # (rofi/Dunst run under XWayland initially — no changes needed)
  xdg.configFile."rofi/config.rasi".source = ../i3/rofi-config.rasi; # extract from i3 module if desired; else leave as-is (shared via i3 module)
  xdg.configFile."dunst/dunstrc".source = ../i3/dunstrc;            # same
}
```

Create `home-manager/modules/sway/config` — the sway session config (port of i3 bindsyms + these sections):

```ini
# === output / layout ===
output eDP-1 { mode 1920x1200@120Hz position 0,0 bg #282a36 solid_color }
output DP-1-3 { mode 1920x1080@60Hz position 1920,0 }
output DP-1-4 { mode 1360x768@60Hz position 3840,0 }
output DP-1   { mode 1920x1080@60Hz position 1920,0 }
output DP-2   { mode 1920x1080@60Hz position 3840,0 }

# === workspace→output pinning (replaces move-workspaces) ===
workspace 1 output DP-1-3 DP-1
workspace 2 output eDP-1
workspace 3 output DP-1-4 DP-2

# === input ===
input "type:keyboard" {
  xkb_layout "de"
  xkb_options "caps:escape"
}

# === keybindings ===
# port the full $mod binding set from home-manager/modules/i3/config (bindsym)
# including window-kill, focus, split, layout, floating, workspace switching,
# restart/exit. Add lock + scratchpad-equivalent bindings:
bindsym $mod+Escape exec swaylock -f

# === autostart ===
exec_always sway-autostart

# === xwayland (dunst/rofi/gtk applets) ===
xwayland enable
```

- [ ] **Step 1:** Create the sway module + config files (port bindings from `modules/i3/config`, Dracula rofi/dunst from `modules/i3/default.nix`).
- [ ] **Step 2:** Add `./sway` to the imports list in `home-manager/modules/x11.nix`.
- [ ] **Step 3:** Validate config syntax: generate the config and run `sway --validate <config>` (or `nixos-rebuild build` then `sway -c <built-config> --validate`).
- [ ] **Step 4:** `sudo nixos-rebuild build` — expected: success.
- [ ] **Step 5:** Commit: `feat(home-manager): add sway module (config, autostart, xwayland) for i3 replacement`.

### Task 3: Rewrite `hosts/coltrane/lock.nix` (swaylock + swayidle)

**Files:**
- Modify: `hosts/coltrane/lock.nix`

**Interfaces:**
- Consumes: Task 1 pinning (workspace snapshot/replay is no longer needed).
- Produces: swaylock + swayidle service set; `~/.config/swaylock/config`; lock keybind `$mod+Escape` (Task 2).

Replace the whole file body:
```nix
{ pkgs, ... }:  # pkgs unused after removing i3lock/xss-lock snapshot logic
{
  programs.swaylock.enable = true;

  programs.swayidle = {
    enable = true;
    events = [
      { event = "before-sleep"; command = "swaylock -f"; }
    ];
    timeouts = [
      { timeout = 300; command = "swaylock -f"; }   # idle lock
    ];
  };

  # Dracula lock (mirrors old i3lock-color ring) — /etc/swaylock or user config
  xdg.configFile."swaylock/config".text = ''
    color=282a36
    inside-color=282a36cc
    ring-color=6272a4ff
    ring-ver-color=8be9fdff
    ring-wrong-color=ff5555ff
    keyhl-color=bd93f9ff
    bshl-color=ff79c6ff
    line-color=00000000
    inside-clear-color=282a36cc
    text-color=f8f8f2ff
    indicator-radius=110
    indicator-thickness=8
    font=JetBrainsMono Nerd Font
    clock
    timestr=%H:%M:%S
    datestr=%A, %-d. %B
  '';
}
```

**Important:** keep `--no-dpms` behavior. swaylock does not DPMS by default; do **not** add `dpms on`/screensaver flags. The suspend-gating role the old `--transfer-sleep-lock` fd-trick played is now handled by swayidle `before-sleep` (it holds the sleep lock until swaylock returns).

- [ ] **Step 1:** Rewrite `hosts/coltrane/lock.nix` as above. Remove the `lock` shell script + workspace snapshot (i3-msg/xrandr) — no longer needed.
- [ ] **Step 2:** `sudo nixos-rebuild build` — expected: success.
- [ ] **Step 3:** Commit: `refactor(coltrane): lock via swaylock+swayidle, drop i3 workspace snapshot`.

### Task 4: Strip i3 coupling from `hosts/coltrane/autorandr.nix`

**Files:**
- Modify: `hosts/coltrane/autorandr.nix`

**Interfaces:**
- Consumes: Task 1 defaultSession (sway), Task 2 sway config output handling.
- Produces: autorandr kept installed + profiles for reference, but the i3 hooks/service override removed and nothing calls `autorandr` at session start.

- In `autorandr.nix`, remove the `systemd.services.autorandr` override block entirely (the `environment.DISPLAY=:0` / `XAUTHORITY` / `ExecStartPre` / i3 hooks are X+i3-only).
- Remove `sharedHooks` preswitch/postswitch (the `i3-msg get_workspaces` / `move workspace to output` logic) — now owned by sway workspace pinning.
- Keep `services.autorandr.enable = true` + `profiles` (reference data; inert under sway since nothing invokes autorandr).
- Confirm Task 2's `sway-autostart` does **not** call `autorandr -c` and drops `xsetroot`/`xset`.

- [ ] **Step 1:** Strip the i3 hooks + service override from `autorandr.nix`.
- [ ] **Step 2:** `sudo nixos-rebuild build` — expected: success.
- [ ] **Step 3:** Commit: `refactor(coltrane): drop i3 autorandr hooks, keep profiles (sway pins workspaces/outputs)`.

### Task 5: `fix-isy-hub.nix` — drop the boot `autorandr --change`

**Files:**
- Modify: `hosts/coltrane/fix-isy-hub.nix`

**Interfaces:**
- Consumes: Task 2 sway output hotplug (sway applies config when DP-1-3/1-4 appear after the rebind).
- Produces: hub rebind retained; no autorandr invocation.

Keep the udev rules + `isy-hub-mst-init` rebind loop unchanged (that is the actual MST enumeration fix). Remove the trailing block:
```nix
XAUTH=$(ls /run/user/*/Xauthority 2>/dev/null | head -1)
if [ -n "$XAUTH" ]; then
  XUSER=$(stat -c '%U' "$XAUTH")
  runuser -u "$XUSER" -- env DISPLAY=:0 XAUTHORITY="$XAUTH" \
    ${pkgs.autorandr}/bin/autorandr --change --match-edid --default mobile || true
fi
```
(sway's output hotplug handler applies config when the MST sub-ports appear; the `sleep`/grep wait loop already ensures they exist before sway is expected to pick them up.)

- [ ] **Step 1:** Remove the autorandr tail from `fix-isy-hub.nix`.
- [ ] **Step 2:** `sudo nixos-rebuild build` — expected: success.
- [ ] **Step 3:** Commit: `refactor(coltrane): drop autorandr from ISY hub init (sway hotplug handles outputs)`.

### Task 6: Verify + switch runbook (user runs the switch)

**Files:** none (operations runbook)

- [ ] **Step 1:** `sudo nixos-rebuild build` on the whole set — success.
- [ ] **Step 2:** Validate generated sway config: `sway --validate <config-path produced by home-manager>`.
- [ ] **Step 3:** **User:** `sudo nixos-rebuild switch`, then in lightdm select **Sway**.
- [ ] **Step 4:** **User tests:** boot to sway; dock/undock workspace restore (ws1→middle, ws3→right, ws2→eDP); suspend via lid → screen locks before suspend (`before-sleep`), external monitors recover or honestly report MST wedge; keyboard `de` + `caps:escape`.
- [ ] **Step 5:** **Revert path:** pick **i3** in lightdm (session) for the bare-WM fallback; or to fully undo, `git checkout` the Task 1–5 commits.

---

## Self-review notes

- **Spec coverage:** session enable (T1), config/autostart (T2), lock (T3), output/workspace automation teardown (T4), hub init (T5), validation+runbook (T6). All covered.
- **Placeholders:** none — the two `# extract from i3 module` notes in Task 2 point at concrete source files to copy from; no "implement later" gaps.
- **Type consistency:** `output`/`workspace` port names (`DP-1-3`, `DP-1-4`, `DP-1`, `DP-2`, `eDP-1`) and modes match the autorandr profile facts everywhere.

## Implementation-time verifications (do not skip)

1. Confirm `programs.sway.enable` leaves lightdm as the DM (does not pull in another display manager / auto-login).
2. Confirm sway preserves the `DP-1-3` / `DP-1-4` MST connector names under wlroots (same DRM connectors as X — expected, but verify at runtime after switch).
