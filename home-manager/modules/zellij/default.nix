{
  pkgs,
  ...
}:
let
  # Backing shell commands for the zjstatus powerline segments below — no
  # native zellij/zjstatus widget for battery/cpu/ram, so shell out (same as
  # tmux-dracula's plugins do).
  statusbarMetrics = pkgs.writeShellApplication {
    name = "zellij-statusbar-metrics";
    text = ''
      case "$1" in
      battery)
        cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "")
        st=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "")
        # matches .tmux-dracula/battery.sh exactly: blank only while
        # actually discharging or at a full charge; AC for every other
        # status (Charging, "Not charging" while plugged in but topped
        # off, Unknown, ...) -- that's its default case, not just "Charging".
        case "$st" in
          Discharging | discharging) stat_word="" ;;
          Full | high) stat_word="" ;;
          *) stat_word="AC" ;;
        esac
        echo "♥ $stat_word $cap" | tr -s ' '
        ;;
      cpu)
        # two /proc/stat samples 1s apart -> real (not load-avg-proxied) CPU%
        read -r _ a b c i d e f g _ _ < /proc/stat
        sleep 1
        read -r _ a2 b2 c2 i2 d2 e2 f2 g2 _ _ < /proc/stat
        t1=$((a + b + c + i + d + e + f + g))
        t2=$((a2 + b2 + c2 + i2 + d2 + e2 + f2 + g2))
        awk -v i1="$i" -v i2="$i2" -v t1="$t1" -v t2="$t2" \
          'BEGIN { printf "⚙️  %.0f%%", 100 * (1 - (i2 - i1) / (t2 - t1)) }'
        ;;
      ram)
        free -g | awk '/^Mem:/ { printf "💻 %dGB/%dGB", $3, $2 }'
        ;;
      esac
    '';
  };

  # Auto-renames tabs to the focused pane's running command (falls back to
  # cwd) -- zellij has no built-in equivalent of tmux's automatic-rename.
in
{
  # zellij writes an auto-generated default config.kdl on first run; force ours
  # over it so the managed keybinds/theme actually apply.
  xdg.configFile."zellij/config.kdl".force = true;

  # A file named `default.kdl` in the layout dir overrides zellij's built-in
  # default layout. Needed to swap the plain status-bar/tab-bar plugins for
  # zjstatus's powerline bar (dracula, matching tmux/default.nix's
  # tmux-powerline look: icon, tabs, then battery/cpu/ram/clock segments
  # chained with powerline arrows).
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

                    format_left   "#[fg=$dim,bg=$green,bold]  🐧  #[fg=$green,bg=$dim]{tabs}"
                    format_center ""
                    format_right  "{command_battery}{command_cpu}{command_ram}{datetime}"
                    format_space  "#[bg=$dim]"

                    border_enabled "false"

                    // : U+E0B0 nerd-font powerline arrow. fg = the color it's leaving,
                    // bg = the color it's entering — that paints the triangular cut.
                    tab_normal "#[fg=$fg,bg=$dim] {index} {name} "
                    tab_active "#[fg=$dim,bg=$purple]#[fg=$bg,bg=$purple,bold] {index} {name} #[fg=$purple,bg=$dim]"

                    command_battery_command  "${statusbarMetrics}/bin/zellij-statusbar-metrics battery"
                    command_battery_format   "#[fg=$dim,bg=$pink]#[fg=$bg,bg=$pink,bold] {stdout} #[fg=$pink,bg=$orange]"
                    command_battery_interval "15"

                    command_cpu_command  "${statusbarMetrics}/bin/zellij-statusbar-metrics cpu"
                    command_cpu_format   "#[fg=$bg,bg=$orange,bold] {stdout} #[fg=$orange,bg=$cyan]"
                    command_cpu_interval "5"

                    command_ram_command  "${statusbarMetrics}/bin/zellij-statusbar-metrics ram"
                    command_ram_format   "#[fg=$bg,bg=$cyan,bold] {stdout} #[fg=$cyan,bg=$blue]"
                    command_ram_interval "15"

                    datetime          "#[fg=$fg,bg=$blue,bold]  {format} "
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
  xdg.configFile."fish/conf.d/zellij.fish".text = ''
    if status is-interactive; and not set -q ZELLIJ
        set -gx ZELLIJ_AUTO_ATTACH true
        set -gx ZELLIJ_AUTO_EXIT true
        ${pkgs.zellij}/bin/zellij attach local -c
        kill $fish_pid
    end
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
      post_command_discovery_hook "echo $RESURRECT_COMMAND | sed -E '/--continue/ { p; d; }; s#^(([^ ]*/)?(pi|claude))$#\\1 --continue#; t; s#^(([^ ]*/)?(pi|claude)) #\\1 --continue #; t'"

      // tmux-style prefix: C-a enters locked (prefix-following) mode
      keybinds {
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
              // live tab-scroll overview: Ctrl-t works unprefixed too, this
              // just bridges it under the prefix like everything else here
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
      }

      // Tab names are set by the shell (`wip` etc. via `zellij action
      // rename-tab`). The old tab-rename wasm poller was removed: zellij
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
