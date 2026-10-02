{
  pkgs,
  lib,
  ...
}:
let
  # Glyphs, the Dracula palette and every metric's colour/threshold, shared with
  # the waybar bar so the two cannot disagree -- see
  # home-manager/lib/statusbar.nix. Here they are rendered into zjstatus'
  # dialect: the layout's color_* vars, the command_*_format strings, and the
  # shell script's glyphs/colours.
  statusbar = import ../../lib/statusbar.nix { inherit lib; };
  segments = statusbar.segments;
  char = statusbar.char;

  # zjstatus names palette entries for itself: $bg/$dim/$fg, and a short name
  # per colour (its own examples and docs use `blue` for Dracula's @comment).
  zjVars = {
    bg = statusbar.palette.background;
    dim = statusbar.palette.selection;
    fg = statusbar.palette.foreground;
    green = statusbar.palette.green;
    purple = statusbar.palette.purple;
    pink = statusbar.palette.pink;
    orange = statusbar.palette.orange;
    cyan = statusbar.palette.cyan;
    blue = statusbar.palette.comment;
  };
  # Cosmetic only (KDL is whitespace-insensitive): line 1 of the interpolated
  # block inherits the layout line's own indentation, so only the rest need it,
  # and only because the layout string indents it to 20 - the 4 spaces Nix
  # strips from the string's common indent.
  indent = "                ";
  zjColorLines = lib.concatStringsSep ("\n" + indent) (
    lib.mapAttrsToList (name: hex: "color_${name} " + lib.strings.escapeNixString hex) zjVars
  );

  # A metric's zjstatus format: its palette colour, bold, on the bar's $dim.
  metricFormat = segment: "#[fg=$" + segments.${segment}.color + ",bg=$dim,bold] {stdout} ";

  # The shell script prints a raw SGR when a value crosses a threshold (zjstatus
  # parses `#[fg=...]` only in its own format string, never in a command's
  # stdout), so each warning/critical/status colour needs its `r;g;b`.
  sgrOf = segment: state: statusbar.sgr statusbar.palette.${(statusbar.stateOf segment state).color};

  # Thresholds the script compares against, and the SGR parameters it prints
  # when a value crosses one.
  at = segment: state: (statusbar.stateOf segment state).at;
  battery = segments.battery;

  # zellij's own UI colours -- panes, frames, tab bar, tables/lists, exit codes,
  # multiplayer cursors. Not a palette: zellij's theme schema is one block per
  # component, each naming base/background/emphasis_0..3, so this is the role
  # assignment table, with the colours themselves taken from the palette above
  # (null = zellij's "terminal default", what the frame/exit-code backgrounds
  # use). Spelled out because a plugin cannot read a theme -- zellij-tile
  # exposes none -- so the bar needs its own colour_* vars too.
  #
  # Components and their order follow the theme this replaced; the generator
  # below emits exactly the `themes { custom-dracula { ... } }` block that used
  # to be typed out here as 94 `r g b` triplets.
  #
  # Deliberately *not* zellij's bundled `dracula` theme, nor dracula/zellij:
  # both paint panes with #000000, which is not a Dracula colour (the spec has
  # nothing darker than Background #282a36, and even its AnsiBlack is #21222c),
  # and neither uses Selection #44475a or Purple #bd93f9 at all. Every value in
  # the table below is a spec colour, which is the same "dracula, not void" call
  # the layout comment above makes.
  themeColors = [
    {
      name = "text_unselected";
      roles = {
        base = "foreground";
        background = "background";
        emphasis_0 = "orange";
        emphasis_1 = "cyan";
        emphasis_2 = "green";
        emphasis_3 = "pink";
      };
    }
    {
      name = "text_selected";
      roles = {
        base = "foreground";
        background = "selection";
        emphasis_0 = "orange";
        emphasis_1 = "cyan";
        emphasis_2 = "green";
        emphasis_3 = "pink";
      };
    }
    {
      name = "ribbon_unselected";
      roles = {
        base = "foreground";
        background = "selection";
        emphasis_0 = "red";
        emphasis_1 = "orange";
        emphasis_2 = "cyan";
        emphasis_3 = "pink";
      };
    }
    {
      name = "ribbon_selected";
      roles = {
        base = "background";
        background = "purple";
        emphasis_0 = "background";
        emphasis_1 = "selection";
        emphasis_2 = "green";
        emphasis_3 = "pink";
      };
    }
    {
      name = "table_title";
      roles = {
        base = "green";
        background = "background";
        emphasis_0 = "orange";
        emphasis_1 = "cyan";
        emphasis_2 = "green";
        emphasis_3 = "pink";
      };
    }
    {
      name = "table_cell_selected";
      roles = {
        base = "foreground";
        background = "selection";
        emphasis_0 = "orange";
        emphasis_1 = "cyan";
        emphasis_2 = "green";
        emphasis_3 = "pink";
      };
    }
    {
      name = "table_cell_unselected";
      roles = {
        base = "foreground";
        background = "background";
        emphasis_0 = "orange";
        emphasis_1 = "cyan";
        emphasis_2 = "green";
        emphasis_3 = "pink";
      };
    }
    {
      name = "list_selected";
      roles = {
        base = "foreground";
        background = "selection";
        emphasis_0 = "orange";
        emphasis_1 = "cyan";
        emphasis_2 = "green";
        emphasis_3 = "pink";
      };
    }
    {
      name = "list_unselected";
      roles = {
        base = "foreground";
        background = "background";
        emphasis_0 = "orange";
        emphasis_1 = "cyan";
        emphasis_2 = "green";
        emphasis_3 = "pink";
      };
    }
    {
      name = "frame_unselected";
      roles = {
        base = "selection";
        background = null;
        emphasis_0 = "selection";
        emphasis_1 = "selection";
        emphasis_2 = "selection";
        emphasis_3 = "selection";
      };
    }
    {
      name = "frame_selected";
      roles = {
        base = "purple";
        background = null;
        emphasis_0 = "purple";
        emphasis_1 = "cyan";
        emphasis_2 = "green";
        emphasis_3 = "pink";
      };
    }
    {
      name = "frame_highlight";
      roles = {
        base = "pink";
        background = null;
        emphasis_0 = "pink";
        emphasis_1 = "cyan";
        emphasis_2 = "green";
        emphasis_3 = "orange";
      };
    }
    {
      name = "exit_code_success";
      roles = {
        base = "green";
        background = null;
        emphasis_0 = "green";
        emphasis_1 = "green";
        emphasis_2 = "green";
        emphasis_3 = "green";
      };
    }
    {
      name = "exit_code_error";
      roles = {
        base = "red";
        background = null;
        emphasis_0 = "red";
        emphasis_1 = "red";
        emphasis_2 = "red";
        emphasis_3 = "red";
      };
    }
    {
      name = "multiplayer_user_colors";
      roles = {
        player_1 = "pink";
        player_2 = "cyan";
        player_3 = "green";
        player_4 = "yellow";
        player_5 = "purple";
        player_6 = "orange";
        player_7 = "red";
        player_8 = "selection";
        player_9 = "cyan";
        player_10 = "pink";
      };
    }
  ];
  themeRoleOrder = [
    "base"
    "background"
    "emphasis_0"
    "emphasis_1"
    "emphasis_2"
    "emphasis_3"
  ]
  ++ map (n: "player_${toString n}") (lib.range 1 10);
  themeValue =
    color:
    if color == null then
      "0" # zellij's terminal default
    else
      lib.concatStringsSep " " (map toString (statusbar.rgb statusbar.palette.${color}));
  themeKdl = lib.concatStringsSep "\n        " (
    map (
      component:
      component.name
      + " {\n"
      + lib.concatStringsSep "\n" (
        map (role: "            ${role} ${themeValue component.roles.${role}}") (
          lib.filter (role: lib.hasAttr role component.roles) themeRoleOrder
        )
      )
      + "\n        }"
    ) themeColors
  );

  # Backing shell commands for the zjstatus powerline segments below — no
  # native zellij/zjstatus widget for battery/cpu/ram/disk, so shell out (same
  # any tmux status plugin does).
  statusbarMetrics = pkgs.writeShellApplication {
    name = "zellij-statusbar-metrics";
    text = ''
      case "$1" in
      battery)
      	cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "")
      	st=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "")
      	# blank only while actually discharging or at a full charge; the AC
      	# word -- from the same entry in home-manager/lib/statusbar.nix that
      	# waybar's format-charging / format-not-charging / format-plugged print
      	# -- for every other status (Charging, "Not charging" while plugged in
      	# but topped off, Unknown, ...). The default case, not just "Charging".
      	case "$st" in
      	Discharging | discharging) stat_word="" ;;
      	Full | high) stat_word="" ;;
      	*) stat_word="${battery.word}" ;;
      	esac
      	# Same icons and bucketing as waybar's battery format-icons: cap/n
      	# (0-19/20-39/40-59/60-79/80-100 for the five below), capped at the last
      	# icon. Icons, thresholds and colours all come from
      	# home-manager/lib/statusbar.nix.
      	icons=(${lib.concatMapStringsSep " " char battery.icons})
      	idx=$((''${cap:-0} / ${toString (100 / (lib.length battery.icons))}))
      	last=${toString ((lib.length battery.icons) - 1)}
      	[ "$idx" -gt "$last" ] && idx=$last
      	# Same colours as waybar's battery CSS, from the same data: its
      	# charging/full/plugged classes green, then warning (<=${toString (at "battery" "warning")}%) yellow
      	# and critical (<=${toString (at "battery" "critical")}%) red. Green is decided first because waybar's
      	# CSS paints a charging battery green even while the charge is low, and
      	# waybar's classes are not the raw sysfs status -- src/modules/battery.cpp
      	# resolves it: a status of "Unknown" goes through the AC adapter (full at
      	# 100%, else plugged while the adapter is online), and "Discharging" or
      	# "Not charging" become "Plugged" whenever the adapter is online -- the TLP
      	# charge-threshold case, which is why waybar gives Plugged priority. The
      	# adapter is looked up by the names it goes by (AC, ADP1); waybar takes the
      	# last /sys/class/power_supply node that has an online file, which the USB-C
      	# port nodes also satisfy.
      	ac=""
      	for d in /sys/class/power_supply/AC /sys/class/power_supply/ADP*; do
      		[ -e "$d/online" ] && ac="$d" && break
      	done
      	plugged=""
      	if [ -n "$ac" ] && [ "$(cat "$ac/online" 2>/dev/null)" = 1 ] \
      		&& [ "$(cat "$ac/status" 2>/dev/null)" != Discharging ]; then
      		plugged=1
      	fi
      	case "$st" in
      	"" | Unknown | unknown)
      		if [ "''${cap:-0}" -eq 100 ]; then eff=Full
      		elif [ -n "$plugged" ]; then eff=Plugged
      		else eff=Discharging; fi
      		;;
      	Discharging | "Not charging")
      		if [ -n "$plugged" ]; then eff=Plugged; else eff="$st"; fi
      		;;
      	*) eff="$st" ;;
      	esac
      	esc=$(printf '\033')
      	sgr=""
      	case "$eff" in
      	Charging | Full | Plugged) sgr="''${esc}[${sgrOf "battery" "charging"}m" ;;
      	*)
      		if [ -n "$cap" ]; then
      			[ "$cap" -le ${toString (at "battery" "warning")} ] && sgr="''${esc}[${sgrOf "battery" "warning"}m"
      			[ "$cap" -le ${toString (at "battery" "critical")} ] && sgr="''${esc}[${sgrOf "battery" "critical"}m"
      		fi
      		;;
      	esac
      	echo "''${sgr}''${icons[$idx]} $stat_word $cap" | tr -s ' '
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
      			'BEGIN { d = t2 - t1; printf "${char segments.cpu.glyph} %d%%", (d > 0 ? 100 * (1 - (i2 - i1) / d) : 0) }'
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
          END               { printf "${char segments.memory.glyph} %d%%", (total - avail - arc) / total * 100 }
        ' /proc/meminfo
      	;;
      disk)
      	# waybar's disk module (src/modules/disk.cpp) counts root-reserved
      	# blocks as used: its percentage_used is
      	# (f_blocks - f_bfree) * 100 / f_blocks, truncated by uint math. `df`'s
      	# Use% divides by (used + f_bavail) instead, so it reads one point high
      	# on this ZFS root (11% where waybar reads 10%). stat -f prints the
      	# statvfs fields waybar itself reads: %b = f_blocks, %f = f_bfree (%a
      	# is f_bavail, the one not to use).
      	pct=$(stat -f --format='%b %f' / | awk '{ printf "%d", ($1 - $2) * 100 / $1 }')
      	# Same thresholds and colours as waybar's disk `states`, from the same data.
      	# zjstatus parses `#[fg=...]` only in the format string it is handed
      	# (src/render.rs `from_format_string`), never in a command's stdout, so the
      	# colour switch has to ride along in this script's stdout as a raw SGR
      	# sequence. Safe because zjstatus wraps that stdout in the format's own SGR
      	# and resets after it (`format_string`): only fg is overridden here, bg=$dim
      	# and bold survive, and the next format part sets its own colours anyway.
      	esc=$(printf '\033')
      	sgr=""
      	if [ "$pct" -ge ${toString (at "disk" "warning")} ]; then sgr="''${esc}[${sgrOf "disk" "warning"}m"; fi
      	if [ "$pct" -ge ${toString (at "disk" "critical")} ]; then sgr="''${esc}[${sgrOf "disk" "critical"}m"; fi
      	printf '%s${char segments.disk.glyph} %d%%' "$sgr" "$pct"
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
  # session name, then tabs on the left; battery/cpu/ram/disk/clock on the right,
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
                    ${zjColorLines}

                    format_left   "{mode}#[fg=$bg,bg=$purple,bold] {session} #[fg=$fg,bg=$dim]{tabs}"
                    format_center ""
                    // order matches waybar's modules-right: cpu, memory,
                    // disk, battery, clock (its network modules have no
                    // zellij equivalent, so they're just skipped here).
                    format_right  "{command_cpu}#[fg=$bg,bg=$dim]│{command_ram}#[fg=$bg,bg=$dim]│{command_disk}#[fg=$bg,bg=$dim]│{command_battery}#[fg=$bg,bg=$dim]│{datetime}"
                    format_space  "#[bg=$dim]"

                    // No format_hide_on_overlength: it drops a whole part (all
                    // 55 cols of metrics+clock) the moment one col doesn't fit,
                    // and the parts never actually overlap -- zjstatus appends
                    // left + get_spacer + right, and the spacer is
                    // `cols.saturating_sub(left+right)` (src/config.rs), so
                    // zero means right starts flush against left and merely runs
                    // off the right edge. The clip already eats the clock's
                    // date/seconds first, which is the graceful version. The
                    // long-name bug is handled at the source instead: the name
                    // bound in zellij_tab_rename (fish) -- zjstatus itself never
                    // truncates a tab name.

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
                    command_battery_format   "${metricFormat "battery"}"
                    command_battery_interval "15"

                    command_cpu_command  "${statusbarMetrics}/bin/zellij-statusbar-metrics cpu"
                    command_cpu_format   "${metricFormat "cpu"}"
                    command_cpu_interval "5"

                    command_ram_command  "${statusbarMetrics}/bin/zellij-statusbar-metrics ram"
                    command_ram_format   "${metricFormat "memory"}"
                    command_ram_interval "15"

                    command_disk_command  "${statusbarMetrics}/bin/zellij-statusbar-metrics disk"
                    command_disk_format   "${metricFormat "disk"}"
                    command_disk_interval "30"

                    datetime          "#[fg=$blue,bg=$dim,bold] ${char segments.clock.glyph} {format} "
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
        # Bound the name here, at the one funnel both setters below route
        # through, not in each of them: zjstatus never truncates a tab name and
        # its tabs widget is unbounded, so a single long name (a deep directory,
        # a store path `zellij_tab_running` reduced to its basename) eats the
        # right half of the bar. Keep the head -- the part that identifies it.
        test (string length -- $name) -gt 20; and set name (string sub -l 19 -- $name)"…"
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
      # The visual bell: a BEL from a pane flashes that pane's frame and the
      # tab frame, and marks the tab's bell flag -- which is what zjstatus's
      # tab_bell_indicator (layouts/default.kdl) renders as the pink bell.
      # 0.45.1 already defaults this to true
      # (`new_config.options.visual_bell.unwrap_or(true)`,
      # zellij-server/src/lib.rs), so this only pins it locally.
      #
      # Worth knowing why an in-pane bell reads as "not really working":
      # check_and_handle_bell_notifications (zellij-server/src/tab/mod.rs)
      # skips the *focused* pane, so the pane you are looking at gets no
      # persistent marker, only the flash -- and
      # clear_bell_for_focused_pane drops a pending one whenever focus changes.
      # The pink tab badge sticks for mail that arrives while you are looking
      # at another tab, which is the case that actually needs signalling.
      visual_bell = true;
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

      // tmux-style prefix: C-a enters locked (prefix-following) mode, and
      // Ctrl-a is the only key zellij owns -- see the unbind below.
      keybinds {
          // zellij's defaults claim Ctrl-{b,g,h,n,o,p,q,s,t} in every mode but
          // "locked" (its own shared_except "locked" block), so the pane's app
          // never sees them. That is what ate neovim's <C-n>/<C-p> (blink-cmp
          // completion select) and <C-b> (its documentation scroll), plus vim's
          // <C-o> and <C-h> in insert mode. A *top-level* unbind drops a key
          // from every mode and is applied after all binds (zellij-utils/
          // src/kdl/mod.rs, unbind_keys_in_all_modes) -- which is also why the
          // modes below are re-bound on other keys: a global unbind would strip
          // a Ctrl-<same key> bind written further down. Bare Ctrl-t was already
          // unbound for fish's fzf Ctrl-T (insert-file); it is part of the rule
          // now rather than a special case.
          unbind "Ctrl b" "Ctrl g" "Ctrl h" "Ctrl n" "Ctrl o" "Ctrl p" "Ctrl q" "Ctrl s" "Ctrl t"

          normal {
              bind "Ctrl a" { SwitchToMode "locked"; }
          }
          locked {
              // Esc leaves locked mode; bare Ctrl-g used to do the same, but it
              // belongs to the app now.
              bind "Esc" { SwitchToMode "Normal"; }

              // zellij's own modes, prefixed now: r/m are the continuous ones
              // (h/j/k/l or arrows act repeatedly, Esc leaves), the rest are
              // one-shot entries. Pane mode is left out on purpose -- it only
              // re-exposes what the prefix already has (h/j/k/l focus, x close,
              // z fullscreen, splits, f floating), and inside it `z` means
              // "toggle pane frames", a different job from the Ctrl-a z in
              // muscle memory.
              bind "r" { SwitchToMode "Resize"; } // arrows/hjkl resize until Esc
              bind "m" { SwitchToMode "Move"; }   // arrows/hjkl move the pane; n/p rotate
              bind "[" { SwitchToMode "Scroll"; } // tmux's prefix-[ copy mode
              bind "s" { SwitchToMode "Scroll"; }
              bind "t" { SwitchToMode "Tab"; }     // tab overview
              // The way out of zellij itself: prefix + d only detaches.
              bind "q" { Quit; }

              // splits (mirror tmux: v = split-window -h (right), H = split-window (down))
              bind "v" { NewPane "Right"; SwitchToMode "Normal"; }
              bind "H" { NewPane "Down"; SwitchToMode "Normal"; }
              // tmux defaults: " = split down (vertical), % = split right (horizontal)
              bind "\"" { NewPane "Down"; SwitchToMode "Normal"; }
              bind "%" { NewPane "Right"; SwitchToMode "Normal"; }

              // floating layer, on the prefix (tmux has no equivalent, so this
              // is the one non-tmux key here). Toggle means "open a floating
              // window" and "hide it again": tab/mod.rs toggle_floating_panes
              // spawns a new floating pane when the layer holds none
              // (last_selectable_floating_pane_id() == None), else it just
              // hides/shows and refocuses what is already there. The default
              // Alt-f still does the same thing unprefixed.
              bind "f" { ToggleFloatingPanes; SwitchToMode "Normal"; }

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
              // Dracula red, from the same table as everything else here.
              color "${statusbar.palette.red}"
          }
      }

      // All UI components, with the spec's Background/Foreground/Selection
      // instead of pure black-and-white: zellij's bundled dracula paints panes
      // #000000 and drops Selection and Purple entirely. Values come from
      // home-manager/lib/statusbar.nix (see themes/themeColors there).
      themes {
          custom-dracula {
              ${themeKdl}
          }
      }
    '';
  };
}
