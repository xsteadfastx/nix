{
  pkgs,
  ...
}:
let
  # Backing shell commands for the zjstatus powerline segments below — no
  # native zellij/zjstatus widget for battery/cpu/ram, so shell out (same as
  # any tmux status plugin does).
  statusbarMetrics = pkgs.writeShellApplication {
    name = "zellij-statusbar-metrics";
    text = ''
      case "$1" in
      battery)
        cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "")
        st=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "")
        # blank only while actually discharging or at a full charge; AC for
        # every other status (Charging, "Not charging" while plugged in but
        # topped off, Unknown, ...) -- the default case, not just "Charging".
        case "$st" in
        Discharging | discharging) stat_word="" ;;
        Full | high) stat_word="" ;;
        *) stat_word="AC" ;;
        esac
        # same 5-icon bucketing as waybar's battery format-icons/states:
        # cap/20 (0-19/20-39/40-59/60-79/80-100), capped at the last icon.
        icons=(    )
        idx=$(( ''${cap:-0} / 20 ))
        [ "$idx" -gt 4 ] && idx=4
        echo "''${icons[$idx]} $stat_word $cap" | tr -s ' '
        ;;
      cpu)
        # Delta since the LAST invocation, not an internal 1s sleep-sample:
        # waybar's cpu module (interval=5, matching command_cpu_interval
        # below) computes usage the same way -- a delta between successive
        # polls -- so a same-formula 1s spot-sample here used to disagree
        # with it, sometimes by a lot during a burst. Caching the previous
        # /proc/stat reading gives the same ~5s window waybar uses.
        #
        # Two more waybar details, read off its cpu_usage/linux.cpp and
        # measured against it: it counts iowait as idle
        # (`idle_time = times[3] + times[4]`), and it truncates the percentage
        # (`uint16_t tmp = 100 * ...`). Counting bare idle read 33% where
        # waybar read 10% in the same 5s window -- iowait is ~20% of the ticks
        # on this laptop whenever nix hammers the disk.
        # Deliberately not matched: waybar sums all ten /proc/stat fields, so
        # it double-counts guest/guest_nice (guest time is already inside
        # user); both are 0 here, so this keeps the first eight.
        state="''${XDG_RUNTIME_DIR:-/tmp}/zellij-statusbar-cpu-stat"
        read -r _ a b c i d e f g _ _ </proc/stat
        if [ -f "$state" ]; then
          read -r a1 b1 c1 i1 d1 e1 f1 g1 <"$state"
          t1=$((a1 + b1 + c1 + i1 + d1 + e1 + f1 + g1))
          t2=$((a + b + c + i + d + e + f + g))
          awk -v i1="$((i1 + d1))" -v i2="$((i + d))" -v t1="$t1" -v t2="$t2" \
            'BEGIN { d = t2 - t1; printf " %d%%", (d > 0 ? 100 * (1 - (i2 - i1) / d) : 0) }'
        else
          echo " ..."
        fi
        echo "$a $b $c $i $d $e $f $g" >"$state"
        ;;
      ram)
        # MemTotal - (MemAvailable + ZFS ARC), matching waybar's memory
        # module formula exactly -- memory/linux.cpp sets
        # `memfree = MemAvailable + zfs_size`, because the ARC is a reclaimable
        # cache, not consumed RAM. On this ZFS-root laptop the ARC is ~15 GiB
        # of 31 GiB, so counting it as used read 81% where waybar read 33%.
        # free -g used a different "used" definition again (and rounded to
        # whole GB).
        # Reported as a bare percentage, not usedGB/totalGB -- waybar's
        # memory module (`{percentage}%`) is the same kind of number as its
        # own cpu module, and zellij's cpu case above; GB/GB was a different
        # unit from both.
        # arcstats `size` is bytes; waybar divides by 1024 in integer math.
        # The `|| echo 0` keeps `set -e` (writeShellApplication) from killing
        # the segment on a machine without ZFS, where the file is absent.
        arc=$(awk '$1 == "size" { printf "%d", $3 / 1024 }' /proc/spl/kstat/zfs/arcstats 2>/dev/null || echo 0)
        awk -v arc="''${arc:-0}" '
          /^MemTotal:/     { total = $2 }
          /^MemAvailable:/ { avail = $2 }
          END               { printf "󰍛 %d%%", (total - avail - arc) / total * 100 }
        ' /proc/meminfo
        ;;
      esac
    '';
  };
in
{
  # zellij writes an auto-generated default config.kdl on first run; force ours
  # over it so the managed keybinds/theme actually apply.
  xdg.configFile."zellij/config.kdl".force = true;

  # A file named `default.kdl` in the layout dir overrides zellij's built-in
  # default layout. Needed to swap the plain status-bar/tab-bar plugins for
  # zjstatus's bar (dracula, modeled on zjstatus's own "simple" example:
  # https://github.com/dj95/zjstatus/blob/main/examples/simple.kdl): mode +
  # session name, then tabs on the left; battery/cpu/ram/clock on the right,
  # divided by a thin dim divider instead of the example's "::". Flat --
  # no powerline arrows, matching waybar/neovim. Each segment is just
  # colored text on the one flat $dim bar background, not its own block.
  #
  # The swap_tiled_layout / swap_floating_layout blocks below are zellij's
  # OWN built-ins, copied verbatim from `zellij setup --dump-swap-layout
  # default` (`ui` renamed to `tab`, zjstatus wiki's documented pattern for
  # default_tab_template). A custom default layout silently drops these —
  # that's why Alt+n/swap-layout cycling stopped working; they have to be
  # redeclared here or lost outright.
  xdg.configFile."zellij/layouts/default.kdl".text = ''
    layout {
        swap_tiled_layout name="vertical" {
            tab max_panes=5 {
                pane split_direction="vertical" {
                    pane
                    pane { children; }
                }
            }
            tab max_panes=8 {
                pane split_direction="vertical" {
                    pane { children; }
                    pane { pane; pane; pane; pane; }
                }
            }
            tab max_panes=12 {
                pane split_direction="vertical" {
                    pane { children; }
                    pane { pane; pane; pane; pane; }
                    pane { pane; pane; pane; pane; }
                }
            }
        }
        swap_tiled_layout name="horizontal" {
            tab max_panes=4 {
                pane
                pane
            }
            tab max_panes=8 {
                pane {
                    pane split_direction="vertical" { children; }
                    pane split_direction="vertical" { pane; pane; pane; pane; }
                }
            }
            tab max_panes=12 {
                pane {
                    pane split_direction="vertical" { children; }
                    pane split_direction="vertical" { pane; pane; pane; pane; }
                    pane split_direction="vertical" { pane; pane; pane; pane; }
                }
            }
        }
        swap_tiled_layout name="stacked" {
            tab min_panes=4 {
                pane stacked=true { children; }
            }
        }
        swap_tiled_layout name="half-stacked" {
            tab min_panes=5 {
                pane split_direction="vertical" {
                    pane
                    pane stacked=true { children; }
                }
            }
        }
        swap_floating_layout name="staggered" {
            floating_panes
        }
        swap_floating_layout name="enlarged" {
            floating_panes max_panes=10 {
                pane { x "5%"; y 1; width "90%"; height "90%"; }
                pane { x "5%"; y 2; width "90%"; height "90%"; }
                pane { x "5%"; y 3; width "90%"; height "90%"; }
                pane { x "5%"; y 4; width "90%"; height "90%"; }
                pane { x "5%"; y 5; width "90%"; height "90%"; }
                pane { x "5%"; y 6; width "90%"; height "90%"; }
                pane { x "5%"; y 7; width "90%"; height "90%"; }
                pane { x "5%"; y 8; width "90%"; height "90%"; }
                pane { x "5%"; y 9; width "90%"; height "90%"; }
                pane { x 10; y 10; width "90%"; height "90%"; }
            }
        }
        swap_floating_layout name="spread" {
            floating_panes max_panes=1 {
                pane { y "50%"; x "50%"; }
            }
            floating_panes max_panes=2 {
                pane { x "1%"; y "25%"; width "45%"; }
                pane { x "50%"; y "25%"; width "45%"; }
            }
            floating_panes max_panes=3 {
                pane { y "55%"; width "45%"; height "45%"; }
                pane { x "1%"; y "1%"; width "45%"; }
                pane { x "50%"; y "1%"; width "45%"; }
            }
            floating_panes max_panes=4 {
                pane { x "1%"; y "55%"; width "45%"; height "45%"; }
                pane { x "50%"; y "55%"; width "45%"; height "45%"; }
                pane { x "1%"; y "1%"; width "45%"; height "45%"; }
                pane { x "50%"; y "1%"; width "45%"; height "45%"; }
            }
        }

        default_tab_template {
            children
            pane size=1 borderless=true {
                plugin location="file:${pkgs.unstable.zellijPlugins.zjstatus}" {
                    color_bg     "#282a36"
                    color_dim    "#44475a"
                    color_fg     "#f8f8f2"
                    color_green  "#50fa7b"
                    color_purple "#bd93f9"
                    color_pink   "#ff79c6"
                    color_orange "#ffb86c"
                    color_cyan   "#8be9fd"
                    color_blue   "#6272a4"

                    format_left   "{mode}#[fg=$bg,bg=$purple,bold] {session} #[fg=$fg,bg=$dim]{tabs}"
                    format_center ""
                    // order matches waybar's modules-right: cpu, memory,
                    // battery, clock (its disk/network have no zellij
                    // equivalent, so they're just skipped here).
                    format_right  "{command_cpu}#[fg=$bg,bg=$dim]│{command_ram}#[fg=$bg,bg=$dim]│{command_battery}#[fg=$bg,bg=$dim]│{datetime}"
                    format_space  "#[bg=$dim]"

                    border_enabled "false"

                    // mode + session get their own solid-color chip (not just
                    // colored text on $dim) so the left side reads distinctly
                    // from the flat tabs/metrics -- covers every locked-derived
                    // submode (tab/resize/renametab/...) with the pink "locked"
                    // look; {name} still prints the real mode.
                    mode_normal          "#[fg=$bg,bg=$green,bold] {name} "
                    mode_locked          "#[fg=$bg,bg=$pink,bold] {name} "
                    mode_default_to_mode "locked"

                    tab_normal               "#[fg=$fg,bg=$dim] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
                    tab_active               "#[fg=$purple,bg=$dim,bold,italic] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
                    tab_fullscreen_indicator "□ "
                    tab_sync_indicator       "  "
                    tab_floating_indicator   "󰉈 "
                    // zellij's visual_bell flags a tab with a bell in it, but
                    // zjstatus only renders that if the tab format asks for it:
                    // {bell_indicator} is substituted only when tab_bell_indicator
                    // is set, and the bell formats are used only when they exist.
                    // Without these keys a background-tab bell is invisible.
                    // Pink block, matching mode_locked's style.
                    tab_bell_indicator       "󰂚 "
                    tab_normal_bell          "#[fg=$bg,bg=$pink,bold] {index} {name} {bell_indicator}"
                    tab_normal_flashing_bell "#[fg=$bg,bg=$pink,bold] {index} {name} {bell_indicator}"

                    command_battery_command  "${statusbarMetrics}/bin/zellij-statusbar-metrics battery"
                    command_battery_format   "#[fg=$pink,bg=$dim,bold] {stdout} "
                    command_battery_interval "15"

                    command_cpu_command  "${statusbarMetrics}/bin/zellij-statusbar-metrics cpu"
                    command_cpu_format   "#[fg=$orange,bg=$dim,bold] {stdout} "
                    command_cpu_interval "5"

                    command_ram_command  "${statusbarMetrics}/bin/zellij-statusbar-metrics ram"
                    command_ram_format   "#[fg=$cyan,bg=$dim,bold] {stdout} "
                    command_ram_interval "15"

                    datetime          "#[fg=$blue,bg=$dim,bold] 󰥔 {format} "
                    datetime_format   "%H:%M:%S %d/%m/%Y"
                    datetime_timezone "Europe/Berlin"
                }
            }
        }
    }
  '';

  # `enableFishIntegration` only feeds home-manager's `programs.fish`, which is
  # disabled here (fish is a custom module). Inject zellij's tmux-like auto-attach
  # directly into fish's conf.d: every new interactive shell attaches to the one
  # persistent session instead of spawning another. `$ZELLIJ` is set by zellij in
  # its own panes, so this never nests. `-c` = create the session only if none.
  #
  # Don't run zellij from a bare console login shell: the first shell to hit
  # this spawns the server, which keeps that shell's environment for the
  # session's lifetime, so a pre-sway console shell wedges every later pane
  # without WAYLAND_DISPLAY/SWAYSOCK.
  xdg.configFile."fish/conf.d/zellij.fish".text = ''
    if status is-interactive; and not set -q ZELLIJ
        set -gx ZELLIJ_AUTO_ATTACH true
        set -gx ZELLIJ_AUTO_EXIT true
        ${pkgs.zellij}/bin/zellij attach local -c
        kill $fish_pid
    end
  '';

  programs.fish.functions = {
    # Zellij tab names: the running command while one runs, the directory when
    # the shell is idle -- tmux's automatic-rename, driven from the shell. This
    # is the community pattern (haseebmajid.dev's zellij status bar post is the
    # version most people copy; zellij.fish and the zjstatus discussions do the
    # same thing).
    #
    # NOT a zellij plugin: `PaneUpdate` is only sent on pane-level operations
    # (zellij-server/src/screen.rs), while command changes reach plugins as
    # `CommandChanged` from the pty thread -- which is why `imsuck/tab-rename`
    # and every other title-polling plugin re-asserts stale names (zellij#5482,
    # the same trap the old tab-rename poller here died on).
    #
    # NOT `onVariable = "PWD"` any more: that fired in *every* pane, so a
    # background `cd` renamed the tab out from under whatever the focused pane
    # was doing and a split tab flapped between its shells' cwds. Both hooks
    # below only run in the pane a command was typed in, and zellij_tab_rename
    # drops the rename unless that pane is still its tab's focused one.
    #
    # Plain `rename-tab` renames whichever tab the *client* is looking at, so a
    # long command finishing in a tab you have since left would rename the tab
    # you are on. Resolve this pane's own tab id and target that instead.
    zellij_tab_rename = {
      argumentNames = [ "name" ];
      description = "rename the zellij tab holding this pane, if it is focused there";
      body = ''
        set -q ZELLIJ_PANE_ID; or return
        # columns: TAB_ID ... PANE_ID TYPE TITLE FOCUSED FLOATING EXITED
        set -l m (command zellij action list-panes -t -s 2>/dev/null \
            | string match -r -g "^(\d+)\s.*\sterminal_$ZELLIJ_PANE_ID\s.*\s(true|false)\s+\S+\s+\S+\$")
        test "$m[2]" = true; or return
        command zellij action rename-tab --tab-id $m[1] -- "$name" 2>/dev/null
      '';
    };

    zellij_tab_name = {
      description = "name the zellij tab after the current directory";
      body = ''
        set -q ZELLIJ; or return
        set -l name (basename $PWD)
        test "$PWD" = "$HOME"; and set name "~"
        zellij_tab_rename "$name"
      '';
    };

    # Before a command runs: show what is about to run.
    zellij_tab_running = {
      onEvent = "fish_preexec";
      description = "name the zellij tab after the running command";
      body = ''
        set -q ZELLIJ; or return
        set -l words (string split -n " " -- $argv[1])
        test -n "$words[1]"; or return
        # `sudo nixos-rebuild switch` should read as nixos-rebuild, not sudo.
        # `FOO=1 make` should read as make.
        while test (count $words) -gt 1
            contains -- $words[1] sudo doas command env nohup
            or string match -q -- "*=*" $words[1]
            or break
            set -e words[1]
        end
        set -l cmd (basename -- $words[1])
        # Near-instant commands would only flicker the tab name; the postexec
        # hook restores the directory right after them anyway.
        contains -- $cmd cd ls ll la clear pwd exit; and return
        zellij_tab_rename "$cmd"
      '';
    };

    # After a command finishes: back to the directory. Without this a tab keeps
    # showing the last command forever (that is what the copied-around snippets
    # do -- they only reset on a `z`/zoxide jump).
    zellij_tab_idle = {
      onEvent = "fish_postexec";
      description = "restore the zellij tab name to the current directory";
      body = ''
        set -q ZELLIJ; or return
        zellij_tab_name
      '';
    };
  };

  # new tab/pane: start out named after the cwd (see zellij_tab_rename)
  programs.fish.interactiveShellInit = ''
    zellij_tab_name
  '';

  programs.zellij = {
    enable = true;
    settings = {
      theme = "custom-dracula";
      # keep the session alive (detached) even if the terminal is force-killed
      on_force_close = "detach";
      # session_serialization defaults to true (persists layout to disk so
      # `zellij attach local -c` recreates it even after a reboot kills the
      # server); serialize_pane_viewport additionally keeps scrollback, so a
      # reconnect after a reboot isn't just the layout back but the output too.
      serialize_pane_viewport = true;
      default_shell = "${pkgs.unstable.fish}/bin/fish";
      mouse_mode = true;
      # dracula-border pane frames (full border around each pane)
      pane_frames = true;
      pane_frame_style = "full";
      # ponytail: simple options go in structured `settings`; the keybinds block
      # is raw KDL via extraConfig (home-manager's documented workaround —
      # yaml->kdl conversion of nested keybinds is unreliable).
    };
    extraConfig = ''
      // On session resurrection zellij re-runs the command it serialized per
      // pane. Neither `pi` nor `claude` resumes unless given `--continue`, so
      // rewrite a resurrected `pi` / `claude` (with or without args) to append
      // `--continue`: the discovery hook (sh -c) gets $RESURRECT_COMMAND and
      // its STDOUT is what gets stored. The `/--continue/` guard passes
      // through commands already carrying the flag so we never double-flag.
      //
      // $RESURRECT_COMMAND is the resolved Nix store path (e.g.
      // `/nix/store/…-claude-code-mcp/bin/claude`), never the bare word --
      // match on the basename after the last `/` (or no `/` at all), not an
      // anchored `^pi`/`^claude`, or the rewrite silently never fires.
      //
      // ponytail: only covers `.../pi`/`.../claude` and `.../pi <args>`/
      // `.../claude <args>` shapes; a user-typed `-c` still becomes
      // `--continue -c` (harmless, both mean "continue").
      // post_command_discovery_hook "echo $RESURRECT_COMMAND | sed -E '/--continue/ { p; d; }; s#^(([^ ]*/)?(pi|claude))$#\\1 --continue#; t; s#^(([^ ]*/)?(pi|claude)) #\\1 --continue #; t'"

      // tmux-style prefix: C-a enters locked (prefix-following) mode
      keybinds {
          // zellij's own default binds bare Ctrl-t (shared_except "tab"
          // "locked") to enter Tab mode from every other mode, including
          // normal -- so it swallows the keystroke before fish's fzf
          // Ctrl-T (insert-file) binding ever sees it. Tab mode is still
          // reachable via the prefix ("Ctrl a" then "t", tmux-style).
          unbind "Ctrl t"

          normal {
              bind "Ctrl a" { SwitchToMode "locked"; }
          }
          locked {
              bind "Ctrl g" "Esc" { SwitchToMode "Normal"; }

              // splits (mirror tmux: v = split-window -h (right), H = split-window (down))
              bind "v" { NewPane "Right"; SwitchToMode "Normal"; }
              bind "H" { NewPane "Down"; SwitchToMode "Normal"; }
              // tmux defaults: " = split down (vertical), % = split right (horizontal)
              bind "\"" { NewPane "Down"; SwitchToMode "Normal"; }
              bind "%" { NewPane "Right"; SwitchToMode "Normal"; }

              // vim pane navigation
              bind "h" { MoveFocus "Left"; SwitchToMode "Normal"; }
              bind "j" { MoveFocus "Down"; SwitchToMode "Normal"; }
              bind "k" { MoveFocus "Up"; SwitchToMode "Normal"; }
              bind "l" { MoveFocus "Right"; SwitchToMode "Normal"; }

              // tmux-style pane resize: prefix + arrows
              bind "Left" { Resize "Increase Left"; SwitchToMode "Normal"; }
              bind "Right" { Resize "Increase Right"; SwitchToMode "Normal"; }
              bind "Up" { Resize "Increase Up"; SwitchToMode "Normal"; }
              bind "Down" { Resize "Increase Down"; SwitchToMode "Normal"; }

              // windows -> tabs
              bind "c" { NewTab; SwitchToMode "Normal"; }
              bind "," { SwitchToMode "RenameTab"; }
              // tab overview -- prefixed only (see the top-level unbind above:
              // bare Ctrl-t is freed for fish's fzf Ctrl-T binding).
              bind "t" { SwitchToMode "Tab"; }
              bind "n" { GoToNextTab; SwitchToMode "Normal"; }
              bind "p" { GoToPreviousTab; SwitchToMode "Normal"; }
              bind "1" { GoToTab 1; SwitchToMode "Normal"; }
              bind "2" { GoToTab 2; SwitchToMode "Normal"; }
              bind "3" { GoToTab 3; SwitchToMode "Normal"; }
              bind "4" { GoToTab 4; SwitchToMode "Normal"; }
              bind "5" { GoToTab 5; SwitchToMode "Normal"; }
              bind "6" { GoToTab 6; SwitchToMode "Normal"; }
              bind "7" { GoToTab 7; SwitchToMode "Normal"; }
              bind "8" { GoToTab 8; SwitchToMode "Normal"; }
              bind "9" { GoToTab 9; SwitchToMode "Normal"; }

              // tmux-style pane swapping: } = swap with next, { = swap with previous
              bind "}" { MovePane; SwitchToMode "Normal"; }
              bind "{" { MovePaneBackwards; SwitchToMode "Normal"; }

              // misc
              bind "z" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
              bind "x" { CloseFocus; SwitchToMode "Normal"; }
              bind "d" { Detach; }
              // tmux-style: Tab = last window, Space = next layout
              bind "Tab" { ToggleTab; SwitchToMode "Normal"; }
              bind "Space" { NextSwapLayout; SwitchToMode "Normal"; }
              // tmux's "Ctrl-a w" window list -> zellij's tab overview (a
              // scrollable bar of all tabs at the top). tmux's choose-window has
              // no pane/plugin form; Tab mode is the native equivalent. The
              // session-manager plugin is *sessions* (tmux C-b s), not windows.
              bind "w" { SwitchToMode "Tab"; }
          }

          // zellij's built-in Tab mode treats j/k as down/up and maps them to
          // j = next (right), k = previous (left). Flip the pair so k moves
          // right and j moves left; h/l and the arrow keys keep the defaults.
          tab {
              bind "j" { GoToPreviousTab; }
              bind "k" { GoToNextTab; }
          }
      }

      // Tab names are set by the shell (fish's zellij_tab_* hooks: running
      // command, else cwd). The old tab-rename wasm poller was removed: zellij
      // (zellij-org/zellij#5482) never delivers a PaneUpdate for later OSC
      // title changes, so it kept re-asserting stale names every interval.
      load_plugins {
          // tints a pane red while it runs `ssh <host>` — see /pkgs/zellij-ssh-tint.
          // color is configurable; the plugin passively watches PaneUpdate, no
          // wrapper or remote changes needed.
          "file:${pkgs.unstable.zellij-ssh-tint}" {
              color "#ff5555"
          }
      }

      // full dracula (v2) — all UI components, with #44475a instead of pure
      // black so panes/status bar read as dracula, not void.
      themes {
          custom-dracula {
              text_unselected {
                  base 248 248 242
                  background 40 42 54
                  emphasis_0 255 184 108
                  emphasis_1 139 233 253
                  emphasis_2 80 250 123
                  emphasis_3 255 121 198
              }
              text_selected {
                  base 248 248 242
                  background 68 71 90
                  emphasis_0 255 184 108
                  emphasis_1 139 233 253
                  emphasis_2 80 250 123
                  emphasis_3 255 121 198
              }
              ribbon_unselected {
                  base 248 248 242
                  background 68 71 90
                  emphasis_0 255 85 85
                  emphasis_1 255 184 108
                  emphasis_2 139 233 253
                  emphasis_3 255 121 198
              }
              ribbon_selected {
                  base 40 42 54
                  background 189 147 249
                  emphasis_0 40 42 54
                  emphasis_1 68 71 90
                  emphasis_2 80 250 123
                  emphasis_3 255 121 198
              }
              table_title {
                  base 80 250 123
                  background 40 42 54
                  emphasis_0 255 184 108
                  emphasis_1 139 233 253
                  emphasis_2 80 250 123
                  emphasis_3 255 121 198
              }
              table_cell_selected {
                  base 248 248 242
                  background 68 71 90
                  emphasis_0 255 184 108
                  emphasis_1 139 233 253
                  emphasis_2 80 250 123
                  emphasis_3 255 121 198
              }
              table_cell_unselected {
                  base 248 248 242
                  background 40 42 54
                  emphasis_0 255 184 108
                  emphasis_1 139 233 253
                  emphasis_2 80 250 123
                  emphasis_3 255 121 198
              }
              list_selected {
                  base 248 248 242
                  background 68 71 90
                  emphasis_0 255 184 108
                  emphasis_1 139 233 253
                  emphasis_2 80 250 123
                  emphasis_3 255 121 198
              }
              list_unselected {
                  base 248 248 242
                  background 40 42 54
                  emphasis_0 255 184 108
                  emphasis_1 139 233 253
                  emphasis_2 80 250 123
                  emphasis_3 255 121 198
              }
              frame_unselected {
                  base 68 71 90
                  background 0
                  emphasis_0 68 71 90
                  emphasis_1 68 71 90
                  emphasis_2 68 71 90
                  emphasis_3 68 71 90
              }
              frame_selected {
                  base 189 147 249
                  background 0
                  emphasis_0 189 147 249
                  emphasis_1 139 233 253
                  emphasis_2 80 250 123
                  emphasis_3 255 121 198
              }
              frame_highlight {
                  base 255 121 198
                  background 0
                  emphasis_0 255 121 198
                  emphasis_1 139 233 253
                  emphasis_2 80 250 123
                  emphasis_3 255 184 108
              }
              exit_code_success {
                  base 80 250 123
                  background 0
                  emphasis_0 80 250 123
                  emphasis_1 80 250 123
                  emphasis_2 80 250 123
                  emphasis_3 80 250 123
              }
              exit_code_error {
                  base 255 85 85
                  background 0
                  emphasis_0 255 85 85
                  emphasis_1 255 85 85
                  emphasis_2 255 85 85
                  emphasis_3 255 85 85
              }
              multiplayer_user_colors {
                  player_1 255 121 198
                  player_2 139 233 253
                  player_3 80 250 123
                  player_4 241 250 140
                  player_5 189 147 249
                  player_6 255 184 108
                  player_7 255 85 85
                  player_8 68 71 90
                  player_9 139 233 253
                  player_10 255 121 198
              }
          }
      }
    '';
  };
}
