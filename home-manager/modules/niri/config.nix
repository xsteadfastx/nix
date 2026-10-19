# niri session config: the port of the sway session this replaced (see git).
#
# Generated rather than kept as a plain file, for the same reason the sway one
# is: every command a binding launches resolves to a real store path, so a bind
# cannot silently point at a binary that left home.packages.
#
# The intent is "the same desktop": sway's binds key for key wherever niri has
# the action at all, and where it has none, the dropped sway line is named in a
# comment rather than vanishing. Those comments are the honest diff between the
# two sessions -- read them before judging niri on the probe login.
#
# NOTE: this is a Nix ''...'' string, so a literal ${ added later has to be
# escaped as ''${.
{
  lib,
  pkgs,
  windowSwitch,
}:
let
  # KDL "..."-string literal. Backslash and quote are escapes inside it, and the
  # shell one-liners below carry their own quotes, so they go through here.
  q = s: "\"" + builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s + "\"";

  ghostty = "${pkgs.unstable.ghostty}/bin/ghostty";
  fish = "${pkgs.unstable.fish}/bin/fish";
  wofi = "${pkgs.unstable.wofi}/bin/wofi";
  niri = "${pkgs.niri}/bin/niri";
  notify-send = "${pkgs.libnotify}/bin/notify-send";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  grep = "${pkgs.gnugrep}/bin/grep";
  awk = "${pkgs.gawk}/bin/awk";
  xargs = "${pkgs.findutils}/bin/xargs";
  grim = "${pkgs.grim}/bin/grim";
  slurp = "${pkgs.slurp}/bin/slurp";
  satty = "${pkgs.satty}/bin/satty";
  wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
  swaylock = "${pkgs.swaylock}/bin/swaylock";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  blueman-manager = "${pkgs.blueman}/bin/blueman-manager";
  gopass = "${pkgs.gopass}/bin/gopass";

  # Colours come from the same table the bar, swaync and the lock screen render
  # from (../../lib/statusbar.nix), so the window borders cannot drift away from
  # the Dracula look.
  inherit ((import ../../lib/statusbar.nix { inherit lib; })) palette;

  # palette.background-darker is the translucent bar surface,
  # "rgba(30, 31, 41, 230)"; niri ignores alpha on the overview backdrop, so this
  # is the same colour with the alpha dropped.
  backdrop = "#1e1f29";

  # sway's OSD one-liners, verbatim: notify-send with swaync's
  # x-canonical-private-synchronous stack tag ("replace the previous
  # notification with this value" instead of piling one up per keypress) and
  # int:value for the progress bar the Dracula theme styles.
  volumeNow = "${wpctl} get-volume @DEFAULT_AUDIO_SINK@ | ${awk} '{print int($2*100)}'";
  volumeOsd =
    sign:
    "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%${sign} && ${notify-send} -a volume -u low -h string:x-canonical-private-synchronous:volume -h int:value:$(${volumeNow}) Volume \"$(${volumeNow})%\"";
  muteOsd = "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle && ${notify-send} -a volume -u low -h string:x-canonical-private-synchronous:volume Volume Muted";
  brightnessNow = "${brightnessctl} | ${grep} -oP '\\d+(?=%)'";
  brightnessOsd =
    sign:
    "${brightnessctl} set 5%${sign} && ${notify-send} -a brightness -u low -h string:x-canonical-private-synchronous:brightness -h int:value:$(${brightnessNow}) Brightness \"$(${brightnessNow})%\"";

  # sway's two screenshot binds: a quick region grab to the clipboard, and the
  # same grab opened in satty to annotate first (Enter copies, Escape discards).
  # satty is native Wayland end to end, which is why flameshot is gone.
  clipShot = "${grim} -g \"$(${slurp})\" - | ${wl-copy}";
  sattyShot = "${grim} -g \"$(${slurp})\" - | ${satty} --filename - --output-filename ~/tmp/satty-%Y%m%d-%H%M%S.png --copy-command ${wl-copy} --early-exit copy --actions-on-enter save-to-clipboard";

  # sway's gopass picker: list, filter in wofi, copy the password of the choice.
  gopassPick = "${gopass} ls --flat | ${wofi} --dmenu -p gopass | ${xargs} --no-run-if-empty ${gopass} show -c";

  # Workspaces are dynamic in niri and belong to a monitor: `Mod+3` is the third
  # workspace of the *focused* screen, not "workspace 3 is that screen".
  #
  # sway's twenty (1-10 on $mod, 11-20 on $mod+Ctrl) therefore do not carry over.
  # Only the two that still mean something are declared: focus a workspace of the
  # focused monitor, and move the column to one. The 11-20 half was inherited from
  # sway and was a no-op here -- `focus-workspace 11` does nothing unless a
  # workspace 11 was ever created, and moving a column there creates one nobody
  # ever looks at. Up/down is the natural motion instead (Mod+U/Mod+I, and
  # Mod+Page_Up/Page_Down), which comes from the default block above.
  wsLine =
    mods: action: n:
    "      ${mods}${toString n} { ${action} ${toString n}; }";
  workspaceBinds = lib.concatMapStringsSep "\n" (
    n:
    lib.concatStringsSep "\n" [
      (wsLine "Mod+" "focus-workspace" n)
      (wsLine "Mod+Shift+" "move-column-to-workspace" n)
    ]
  ) (lib.range 1 9);
in
''
  // Generated by home-manager/modules/niri -- do not edit.

  // ── input ────────────────────────────────────────────────────────────────
  // Parity with the sway session this replaced: de layout and caps
  // as escape. Without this a niri login types on a us layout with a real caps
  // lock, i.e. the probe would be judging the keyboard, not the compositor.
  input {
      keyboard {
          xkb {
              layout "de"
              options "caps:escape"
          }
      }
      // sway's default, and what this desktop wants: hovering focuses.
      focus-follows-mouse
  }

  // ── outputs ──────────────────────────────────────────────────────────────
  // The old kanshi profiles, in niri's own dialect. niri matches outputs by make
  // + model + serial, so the connector-name churn under xe/MST does not matter:
  // whichever connector a monitor lands on, its block applies. Refresh rate
  // omitted on purpose -- niri then takes the highest the mode offers, which is
  // what the kanshi profiles spelled out by hand.
  //
  // What does NOT carry over: sway pinned workspaces to outputs (ws1 middle,
  // ws2 laptop, ws3 right, via sway-outputs). niri workspaces belong to a
  // monitor, so there is nothing to pin -- and nothing to re-pin on hotplug.
  output "LG Display 0x078B Unknown" {
      mode "1920x1200"
      position x=0 y=0
      // Explicit, because niri guesses a scale from the panel's physical size
      // and lands on 1.25 here (168 DPI). sway/kanshi had no scaling at all, so
      // the guess made everything on the laptop 25% bigger *and* shrank the
      // logical width to 1536 -- which broke the arrangement: the middle monitor
      // sits at x=1920 and the 384px in between belongs to no output, so the
      // pointer cannot cross from the laptop to the middle screen at all.
      scale 1
  }
  // Samsung SMB2440: middle. The anonymous Avolites TV: right.
  output "Samsung Electric Company SMB2440 H9XZ806373" {
      mode "1920x1080"
      position x=1920 y=0
  }
  output "Avolites Ltd HDTV Unknown" {
      mode "1360x768"
      position x=3840 y=0
  }

  // ── layout / colours ─────────────────────────────────────────────────────
  layout {
      // sway had no gaps, only the 1px border. niri's default is 16px on every
      // side, which is why even a 100%-wide column still left a frame of
      // background around it.
      gaps 0
      // sway fills the workspace with the focused window; niri is
      // scrollable-tiling and its default column is *half* the screen, so a
      // single terminal sat in a half-width column with nothing beside it. This
      // is the one layout setting that makes the two sessions behave the same:
      // a new column takes the full width, and adding a window scrolls a second
      // full-width column in (Mod+R cycles the old presets when you want
      // halves).
      default-column-width { proportion 1.0; }
      // sway's `output * bg #282a36 solid_color`. Global, because niri's
      // per-output `background-color` needs a name per monitor and is
      // deprecated in favour of this.
      background-color "${palette.background}"

      // sway: `default_border pixel 1` with client.focused #6272A4,
      // client.unfocused #282A36, client.urgent #FF5555. niri draws the same
      // thing with `border`: 1px around every window, shrinking it the way a
      // sway pixel border does. The focus ring is off -- it would draw a second
      // outline around the active window on top of this border.
      focus-ring {
          off
      }
      border {
          width 1
          active-color "${palette.comment}"
          inactive-color "${palette.background}"
          urgent-color "${palette.red}"
      }
  }

  // overview backdrop (behind the workspaces in Mod+O and between workspaces
  // when switching). niri's default is a mid grey; dracula's darker surface is
  // what the translucent waybar background is, minus its alpha.
  overview {
      backdrop-color "${backdrop}"
  }

  // ── window rules ─────────────────────────────────────────────────────────
  // sway: `for_window [app_id="org-openstreetmap-josm-Main"] floating disable;
  // layout splitv`. JOSM is wanted tiled, not floating.
  window-rule {
      match app-id="org-openstreetmap-josm-*"
      open-floating false
  }
  // sway moved qemu windows to the scratchpad; niri has no scratchpad, so they
  // float instead -- out of the column grid, one Mod+Shift+Space away.
  window-rule {
      match app-id="Qemu-kvm"
      open-floating true
  }
  window-rule {
      match app-id="Qemu-system-x86_64"
      open-floating true
  }

  // ── binds ───────────────────────────────────────────────────────────────
  // READ THIS BEFORE ADDING A KEY: niri does NOT merge its default binds when a
  // config has a `binds` block. Upstream's defaults live in the config file niri
  // writes on first start, and the wiki is explicit that this section "does not
  // get automatically filled with defaults if you omit it". So every key that
  // is not declared here is dead -- that is why Mod+Shift+<arrow> (monitor
  // focus), Mod+O (overview), Mod+Q (close), Print and the resize keys did
  // nothing at first. The block below is upstream's default set, minus the keys
  // this desktop overrides, plus those overrides.
  binds {
      // ── upstream defaults, kept as-is ────────────────────────────────────
      Mod+Shift+Slash { show-hotkey-overlay; }
      Super+Alt+L { spawn ${q swaylock}; }
      XF86AudioMicMute { spawn-sh ${q "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"}; }
      XF86AudioPlay { spawn-sh ${q "${playerctl} play-pause"}; }
      XF86AudioStop { spawn-sh ${q "${playerctl} stop"}; }
      XF86AudioPrev { spawn-sh ${q "${playerctl} previous"}; }
      XF86AudioNext { spawn-sh ${q "${playerctl} next"}; }

      Mod+O repeat=false { toggle-overview; }
      Mod+Q repeat=false { close-window; }
      Mod+Left { focus-column-left; }
      Mod+Down { focus-window-down; }
      Mod+Up { focus-window-up; }
      Mod+Right { focus-column-right; }
      Mod+Ctrl+Left { move-column-left; }
      Mod+Ctrl+Down { move-window-down; }
      Mod+Ctrl+Up { move-window-up; }
      Mod+Ctrl+Right { move-column-right; }
      // hjkl navigation across monitor edges. niri's defaults put "move" here
      // (Mod+Ctrl+H/J/K/L), which is already on Mod+Shift+H/J/K/L in this config
      // and is invisible with full-width columns anyway -- so the keys are free
      // for what the cursor actually needs: keep walking left/right/up/down and
      // land on the next monitor when the column/edge runs out. Without this,
      // crossing monitors was only possible on the arrow keys.
      Mod+Ctrl+H { focus-column-or-monitor-left; }
      Mod+Ctrl+J { focus-window-or-monitor-down; }
      Mod+Ctrl+K { focus-window-or-monitor-up; }
      Mod+Ctrl+L { focus-column-or-monitor-right; }

      Mod+Home { focus-column-first; }
      Mod+End { focus-column-last; }
      Mod+Ctrl+Home { move-column-to-first; }
      Mod+Ctrl+End { move-column-to-last; }

      // Monitor focus. The arrows only -- Mod+Shift+H/J/K/L is sway's
      // "move window" in this config (see below).
      Mod+Shift+Left { focus-monitor-left; }
      Mod+Shift+Down { focus-monitor-down; }
      Mod+Shift+Up { focus-monitor-up; }
      Mod+Shift+Right { focus-monitor-right; }
      Mod+Shift+Ctrl+Left { move-column-to-monitor-left; }
      Mod+Shift+Ctrl+Down { move-column-to-monitor-down; }
      Mod+Shift+Ctrl+Up { move-column-to-monitor-up; }
      Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
      Mod+Shift+Ctrl+H { move-column-to-monitor-left; }
      Mod+Shift+Ctrl+J { move-column-to-monitor-down; }
      Mod+Shift+Ctrl+K { move-column-to-monitor-up; }
      Mod+Shift+Ctrl+L { move-column-to-monitor-right; }

      // Workspace up/down (the Mod+<digit> keys are further down).
      Mod+Page_Down { focus-workspace-down; }
      Mod+Page_Up { focus-workspace-up; }
      Mod+U { focus-workspace-down; }
      Mod+I { focus-workspace-up; }
      Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
      Mod+Ctrl+Page_Up { move-column-to-workspace-up; }
      Mod+Ctrl+U { move-column-to-workspace-down; }
      Mod+Ctrl+I { move-column-to-workspace-up; }
      Mod+Shift+Page_Down { move-workspace-down; }
      Mod+Shift+Page_Up { move-workspace-up; }
      Mod+Shift+U { move-workspace-down; }
      Mod+Shift+I { move-workspace-up; }

      // Wheel scrolling: workspaces with Mod, columns with Mod+Ctrl.
      Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
      Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
      Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
      Mod+Ctrl+WheelScrollUp cooldown-ms=150 { move-column-to-workspace-up; }
      Mod+WheelScrollRight { focus-column-right; }
      Mod+WheelScrollLeft { focus-column-left; }
      Mod+Ctrl+WheelScrollRight { move-column-right; }
      Mod+Ctrl+WheelScrollLeft { move-column-left; }

      // Column size / position.
      Mod+R { switch-preset-column-width; }
      Mod+Shift+R { switch-preset-column-width-back; }
      Mod+Ctrl+R { reset-window-height; }
      Mod+Ctrl+Shift+R { switch-preset-window-height; }
      Mod+Minus { set-column-width "-10%"; }
      Mod+Equal { set-column-width "+10%"; }
      Mod+Shift+Minus { set-window-height "-10%"; }
      Mod+Shift+Equal { set-window-height "+10%"; }
      Mod+Ctrl+F { expand-column-to-available-width; }
      Mod+C { center-column; }
      Mod+Ctrl+C { center-visible-columns; }

      // Floating / columns.
      Mod+V { toggle-window-floating; }
      Mod+Shift+V { switch-focus-between-floating-and-tiling; }
      Mod+BracketLeft { consume-or-expel-window-left; }
      Mod+BracketRight { consume-or-expel-window-right; }
      Mod+Comma { consume-window-into-column; }
      Mod+Period { expel-window-from-column; }

      // niri's own screenshot UI plus the session keys.
      Print { screenshot; }
      Ctrl+Print { screenshot-screen; }
      Alt+Print { screenshot-window; }
      Mod+Escape { toggle-keyboard-shortcuts-inhibit; }
      Mod+Shift+P { power-off-monitors; }

      // ── this desktop's binds ─────────────────────────────────────────────
      // sway's `$mod+Return`: ghostty running fish. fish's conf.d/zellij.fish
      // auto-attaches the persistent zellij session on every interactive shell,
      // so this is already "ghostty with my zellij" -- no `-e zellij` (which
      // would attach from a shell carrying no session env).
      // niri's own terminal bind is Mod+T -> alacritty, not installed here, so
      // Mod+T stays a dead key. Mod+Return was free.
      Mod+Return repeat=false { spawn ${q ghostty} "-e" ${q fish}; }
      // niri's own default terminal key pointed at alacritty, which is not
      // installed; keep the key, point it at the same terminal.
      Mod+T repeat=false { spawn ${q ghostty} "-e" ${q fish}; }

      // sway: `--release $mod+d wofi --show drun,run`. niri has no release
      // trigger; repeat=false is the equivalent guard.
      Mod+D repeat=false { spawn ${q wofi} "--show" "drun,run"; }

      // sway's window switcher (rofi's `window` mode), same key.
      Mod+Tab repeat=false { spawn ${q windowSwitch}; }

      // sway's gopass picker.
      Mod+P repeat=false { spawn-sh ${q gopassPick}; }

      // sway's blueman bind. (Its tray icon works under waybar now, but this
      // stays as the direct route.)
      Mod+B repeat=false { spawn ${q blueman-manager}; }

  // ── focus and movement ───────────────────────────────────────────────────
  // sway's `focus left|down|up|right` and `move left|down|up|right`.
  //
  // Mod+H/J/K/L is niri's default for focus. Mod+Shift+H/J/K/L is *also* a
  // niri default (focus-monitor), overridden here with sway's move -- monitor
  // focus keeps its other default keys, Mod+Shift+<arrow>.
      Mod+H { focus-column-left; }
      Mod+J { focus-window-down; }
      Mod+K { focus-window-up; }
      Mod+L { focus-column-right; }
      Mod+Shift+H { move-column-left; }
      Mod+Shift+J { move-window-down; }
      Mod+Shift+K { move-window-up; }
      Mod+Shift+L { move-column-right; }

  // ── windows ──────────────────────────────────────────────────────────────
      // sway's `$mod+Shift+q kill`. (niri's own Mod+Q close-window stays.)
      Mod+Shift+Q { close-window; }
      // sway: `$mod+f fullscreen` and `$mod+Shift+f fullscreen toggle global`.
      // niri has a single fullscreen, so it takes sway's key; maximize-column,
      // which niri had on Mod+F, moves to Mod+M (overriding
      // maximize-window-to-edges) to stay reachable.
      Mod+F { fullscreen-window; }
      Mod+M { maximize-column; }
      // sway's `layout tabbed` on the same key as niri's tabbed-column display.
      Mod+W { toggle-column-tabbed-display; }
      // sway's `$mod+Shift+space floating toggle`.
      Mod+Shift+Space { toggle-window-floating; }

  // ── workspaces ───────────────────────────────────────────────────────────
  ${workspaceBinds}

  // ── session ──────────────────────────────────────────────────────────────
      // Reload: niri re-applies the output blocks above from the file it just
      // re-read, so nothing else needs restarting.
      Mod+Shift+C { spawn ${q niri} "msg" "action" "load-config-file"; }

      // sway's `$mod+Shift+e` exited behind a swaynag confirmation. niri's
      // quit is immediate and there is no nag equivalent in the session, so
      // this is the one binding that lost its "are you sure" (niri msg quit
      // has the prompt, but that needs a terminal).
      Mod+Shift+E { quit; }

      // sway's `Control+mod1+l`.
      Ctrl+Alt+L repeat=false { spawn ${q swaylock} "-f"; }

  // ── screenshots ──────────────────────────────────────────────────────────
      // sway: `$mod+Shift+Print` straight to the clipboard,
      // `$mod+Print` through satty. niri's own screenshot UI keeps bare Print.
      Mod+Shift+Print { spawn-sh ${q clipShot}; }
      Mod+Print { spawn-sh ${q sattyShot}; }

  // ── OSDs ─────────────────────────────────────────────────────────────────
      // sway's brightness/volume keys, with swaync standing in for dunst. niri's
      // defaults already change volume/brightness on these keys, but without the
      // OSD, so these replace them rather than adding a second handler.
      XF86MonBrightnessUp allow-when-locked=true { spawn-sh ${q (brightnessOsd "+")}; }
      XF86MonBrightnessDown allow-when-locked=true { spawn-sh ${q (brightnessOsd "-")}; }
      XF86AudioRaiseVolume allow-when-locked=true { spawn-sh ${q (volumeOsd "+")}; }
      XF86AudioLowerVolume allow-when-locked=true { spawn-sh ${q (volumeOsd "-")}; }
      XF86AudioMute allow-when-locked=true { spawn-sh ${q muteOsd}; }
  }

  // Dropped from sway's config, no niri equivalent:
  //   $mod+Shift+backslash / $mod+backslash   split h / split v
  //   $mod+s                                  layout stacking
  //   $mod+e                                  layout toggle split
  //   $mod+space                              focus mode_toggle
  //   $mod+a                                  focus parent
  //   $mod+Shift+w                            sticky toggle
  //   $mod+minus / $mod+Shift+minus           scratchpad show / move
  //   $mod+r mode "resize" + h/j/k/l          resize mode
  // niri has no container tree (columns scroll, so no manual splits and no
  // parent), no floating "mode" to focus-switch into, no sticky windows and no
  // scratchpad. Resizing is niri's Mod+R preset cycling plus Mod+Minus/Equal
  // (-/+10%) and Mod+Shift+{Minus,Equal} for height -- all defaults, so no mode
  // is needed and none is declared above.

  // sway's `xwayland enable`. There is nothing to start here: since 25.08 niri
  // integrates xwayland-satellite itself -- it exports $DISPLAY, creates the X11
  // sockets and spawns the satellite on demand, as long as the binary is on the
  // session PATH (it is, via home.packages in default.nix). Upstream is explicit
  // that a manual spawn-at-startup is wrong and should be removed, so this file
  // deliberately has none. Check `journalctl --user-unit=niri -b` for
  // "listening on X11 socket" if an X11 app (Tor Browser) refuses to start.
''
