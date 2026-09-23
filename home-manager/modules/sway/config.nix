# Sway session config.
#
# Generated here rather than kept as a plain file so every command a binding
# launches resolves to a real store path: a binding can't silently point at a
# binary that left home.packages, and the attrs below are the same ones the
# rest of the repo installs (wofi/ghostty/fish come from nixpkgs-unstable, per
# desktop.nix).
#
# NOTE: this is a Nix ''...'' string, so a literal ${ added later has to
# be escaped as ''${.
{ pkgs }:
''
  # windows key
  set $mod Mod4
  # alt key
  #set $mod Mod1

  font pango: JetBrainsMono Nerd Font Mono 11

  # Use Mouse+$mod to drag floating windows to their wanted position
  floating_modifier $mod

  # === output / layout ===
  # Arrangement + workspace pinning is done dynamically by `sway-outputs` (run at
  # startup and on every output hotplug): laptop (eDP-*) is always left, the
  # Samsung SMB2440 is middle, and the remaining external is right. Connector
  # names are NOT stable under xe/MST, so nothing here hardcodes them.
  output * bg #282a36 solid_color

  # NixOS's session integration (written by programs.sway.enable): imports the
  # Wayland env into the systemd/dbus user environment, then starts
  # sway-session.target so user services (kanshi, swayidle) can bind to it.
  # Without this include sway-session.target never starts and they only ever see
  # the graphical-session.target NixOS starts *before* sway (no WAYLAND_DISPLAY =>
  # ConditionEnvironment unmet => skipped for the whole session).
  include /etc/sway/config.d/*

  # Sway's default, and what we want: hovering a window focuses it, no click
  # needed. It only ever half-worked here because of two sway 1.10+ layer-focus
  # defects -- with `yes`, a launcher could lose its keyboard grab either from
  # hover-focus handing seat focus to a view, or from a `mode hide` swaybar's
  # per-mod-press surface churn stealing it on destroy. Both are fixed for us
  # by the sway patch in overlays/package-overrides.nix (upstream
  # swaywm/sway#9262). Drop that patch -> expect this to break again.
  focus_follows_mouse yes

  # === input ===
  input type:keyboard {
      xkb_layout de
      xkb_options caps:escape
  }

  # start a terminal
  bindsym $mod+Return exec ${pkgs.unstable.ghostty}/bin/ghostty -e ${pkgs.unstable.fish}/bin/fish

  # kill focused window
  bindsym $mod+Shift+q kill

  # wofi's combi: `--show drun,run` (~ rofi's `-combi-modi run#drun`). rofi's
  # ssh mode isn't wanted; its window-switcher is the one thing lost, and that
  # is a small `--dmenu` script over `swaymsg -t get_tree` if it's missed.
  bindsym --release $mod+d exec ${pkgs.unstable.wofi}/bin/wofi --show drun,run

  # window switcher (rofi's `window` mode); sway-window-switch is the same
  # `--dmenu`-over-swaymsg script pattern as sway-outputs. Change the key if
  # Mod4+Tab clashes with something.
  bindsym --release $mod+Tab exec sway-window-switch

  # change focus
  bindsym $mod+h focus left
  bindsym $mod+j focus down
  bindsym $mod+k focus up
  bindsym $mod+l focus right

  # move focused window
  bindsym $mod+Shift+h move left
  bindsym $mod+Shift+j move down
  bindsym $mod+Shift+k move up
  bindsym $mod+Shift+l move right

  # split in horizontal orientation
  bindsym $mod+Shift+backslash split h

  # split in vertical orientation
  bindsym $mod+backslash split v

  # enter fullscreen mode for the focused container
  bindsym $mod+f fullscreen

  # change container layout (stacked, tabbed, toggle split)
  bindsym $mod+s layout stacking
  bindsym $mod+w layout tabbed
  bindsym $mod+e layout toggle split

  # toggle tiling / floating
  bindsym $mod+Shift+space floating toggle

  # change focus between tiling / floating windows
  bindsym $mod+space focus mode_toggle

  # focus the parent container
  bindsym $mod+a focus parent

  # switch to workspace
  bindsym $mod+1 workspace 1
  bindsym $mod+2 workspace 2
  bindsym $mod+3 workspace 3
  bindsym $mod+4 workspace 4
  bindsym $mod+5 workspace 5
  bindsym $mod+6 workspace 6
  bindsym $mod+7 workspace 7
  bindsym $mod+8 workspace 8
  bindsym $mod+9 workspace 9
  bindsym $mod+0 workspace 10

  bindsym $mod+Control+1 workspace 11
  bindsym $mod+Control+2 workspace 12
  bindsym $mod+Control+3 workspace 13
  bindsym $mod+Control+4 workspace 14
  bindsym $mod+Control+5 workspace 15
  bindsym $mod+Control+6 workspace 16
  bindsym $mod+Control+7 workspace 17
  bindsym $mod+Control+8 workspace 18
  bindsym $mod+Control+9 workspace 19
  bindsym $mod+Control+0 workspace 20

  # move focused container to workspace
  bindsym $mod+Shift+1 move container to workspace 1
  bindsym $mod+Shift+2 move container to workspace 2
  bindsym $mod+Shift+3 move container to workspace 3
  bindsym $mod+Shift+4 move container to workspace 4
  bindsym $mod+Shift+5 move container to workspace 5
  bindsym $mod+Shift+6 move container to workspace 6
  bindsym $mod+Shift+7 move container to workspace 7
  bindsym $mod+Shift+8 move container to workspace 8
  bindsym $mod+Shift+9 move container to workspace 9
  bindsym $mod+Shift+0 move container to workspace 10

  bindsym $mod+Shift+Control+1 move container to workspace 11
  bindsym $mod+Shift+Control+2 move container to workspace 12
  bindsym $mod+Shift+Control+3 move container to workspace 13
  bindsym $mod+Shift+Control+4 move container to workspace 14
  bindsym $mod+Shift+Control+5 move container to workspace 15
  bindsym $mod+Shift+Control+6 move container to workspace 16
  bindsym $mod+Shift+Control+7 move container to workspace 17
  bindsym $mod+Shift+Control+8 move container to workspace 18
  bindsym $mod+Shift+Control+9 move container to workspace 19
  bindsym $mod+Shift+Control+0 move container to workspace 20

  # toggle fullscreen mode for a window
  bindsym $mod+Shift+f fullscreen toggle global

  # reload the configuration file. sway's reload re-applies its own (unset)
  # output config, wiping whatever kanshi last set and leaving outputs in
  # connector-enumeration order until something re-triggers it -- confirmed
  # live, twice. Restart kanshi right after so it always self-heals.
  bindsym $mod+Shift+c exec ${pkgs.sway}/bin/swaymsg reload && systemctl --user restart kanshi

  # exit sway (logs you out of your Wayland session)
  bindsym $mod+Shift+e exec ${pkgs.sway}/bin/swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' '${pkgs.sway}/bin/swaymsg exit'

  # sticky window
  bindsym $mod+Shift+w sticky toggle

  mode "resize" {
          bindsym h resize shrink width 10 px or 10 ppt
          bindsym j resize grow height 10 px or 10 ppt
          bindsym k resize shrink height 10 px or 10 ppt
          bindsym l resize grow width 10 px or 10 ppt

          # back to normal: Enter or Escape
          bindsym Return mode "default"
          bindsym Escape mode "default"
  }

  bindsym $mod+r mode "resize"

  # scratchpad
  bindsym $mod+Shift+minus move scratchpad
  bindsym $mod+minus scratchpad show

  # brightness/volume OSDs. These used dunstify with dunst's own stack-tag
  # hint; dunst is gone, so they use notify-send against swaync. The stack tag
  # maps 1:1 onto x-canonical-private-synchronous, which swaync implements for
  # "replace the previous notification with this value" (src/notiModel.vala)
  # -- without it every keypress would pile up a new notification instead of
  # updating one. int:value feeds the progress bar the Dracula theme styles.

  # brightness controls
  bindsym XF86MonBrightnessUp exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set 5%+ && ${pkgs.libnotify}/bin/notify-send -a "brightness" -u low -h string:x-canonical-private-synchronous:brightness -h int:value:$(${pkgs.brightnessctl}/bin/brightnessctl | grep -oP '\d+(?=%)') "Brightness" "$(${pkgs.brightnessctl}/bin/brightnessctl | grep -oP '\d+(?=%)')%"
  bindsym XF86MonBrightnessDown exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set 5%- && ${pkgs.libnotify}/bin/notify-send -a "brightness" -u low -h string:x-canonical-private-synchronous:brightness -h int:value:$(${pkgs.brightnessctl}/bin/brightnessctl | grep -oP '\d+(?=%)') "Brightness" "$(${pkgs.brightnessctl}/bin/brightnessctl | grep -oP '\d+(?=%)')%"

  # audio controls
  bindsym XF86AudioRaiseVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && ${pkgs.libnotify}/bin/notify-send -a "volume" -u low -h string:x-canonical-private-synchronous:volume -h int:value:$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}') "Volume" "$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')%"
  bindsym XF86AudioLowerVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && ${pkgs.libnotify}/bin/notify-send -a "volume" -u low -h string:x-canonical-private-synchronous:volume -h int:value:$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}') "Volume" "$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')%"
  bindsym XF86AudioMute exec --no-startup-id wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && ${pkgs.libnotify}/bin/notify-send -a "volume" -u low -h string:x-canonical-private-synchronous:volume "Volume" "Muted"

  # lock
  bindsym Control+mod1+l exec ${pkgs.swaylock-effects}/bin/swaylock -f

  # bluetooth manager (blueman's tray icon won't render in swaybar — its SNI
  # properties are unsupported — so launch the manager directly)
  bindsym $mod+b exec ${pkgs.blueman}/bin/blueman-manager

  # screenshots — $mod+Shift+Print is a quick region grab straight to
  # clipboard, no editor. $mod+Print opens the same grab in satty to
  # annotate first; Enter copies, Escape discards, both close the window.
  # satty is native Wayland end to end (grim/slurp/satty/wl-copy), unlike
  # flameshot which had to be forced onto XWayland for screen detection and
  # then couldn't get its clipboard writes back out to native Wayland apps.
  bindsym $mod+Shift+Print exec ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.wl-clipboard}/bin/wl-copy
  bindsym $mod+Print exec ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.satty}/bin/satty --filename - --output-filename ~/tmp/satty-%Y%m%d-%H%M%S.png --copy-command "${pkgs.wl-clipboard}/bin/wl-copy" --early-exit copy --actions-on-enter save-to-clipboard

  # run password manager
  bindsym --release $mod+p exec ${pkgs.gopass}/bin/gopass ls --flat | ${pkgs.unstable.wofi}/bin/wofi --dmenu -p gopass | xargs --no-run-if-empty ${pkgs.gopass}/bin/gopass show -c

  # The bar is waybar, but it MUST be declared here as a sway bar too.
  #
  # Reason: waybar's `mode hide` is not waybar watching the modifier itself --
  # Wayland forbids a client grabbing keys, and waybar is not the compositor.
  # Waybar subscribes to sway's bar IPC and reveals on the `visible_by_modifier`
  # flag of a bar_state_update event, and sway only emits those for bars it knows
  # about -- i.e. a block right here. Without it we had a bar that ran happily on
  # all three outputs and could never be revealed (that was the "no bar at all"
  # bug).
  #
  # `swaybar_command` is what hands the process to waybar: sway runs it (as
  # `waybar -b bar-0`, the id sway assigns when none is given) and keeps owning
  # mode/visibility. Consequently waybar must NOT also be started by systemd --
  # see programs.waybar.systemd.enable = false in
  # home-manager/modules/waybar/default.nix, and there is nothing to exec from
  # here either.
  #
  # No `id` is set deliberately: sway then assigns bar-0, and waybar's default
  # bar_id is also bar-0, so they match whether or not sway passes -b along.
  bar {
    swaybar_command ${pkgs.waybar}/bin/waybar
    hidden_state hide
    mode hide
    modifier Mod4
    position top
  }

  client.focused          #6272A4 #6272A4 #F8F8F2 #6272A4   #6272A4
  client.focused_inactive #44475A #44475A #F8F8F2 #44475A   #44475A
  client.unfocused        #282A36 #282A36 #BFBFBF #282A36   #282A36
  client.urgent           #44475A #FF5555 #F8F8F2 #FF5555   #FF5555
  client.placeholder      #282A36 #282A36 #F8F8F2 #282A36   #282A36

  client.background       #F8F8F2

  # border
  default_border pixel 1
  default_floating_border pixel 1
  for_window [app_id="^.*"] border pixel 1

  # josm (found class with xprop)
  for_window [app_id="org-openstreetmap-josm-Main"] floating disable
  for_window [app_id="org-openstreetmap-josm-Main"] layout splitv

  # qemu to scratchpad
  for_window [app_id="Qemu-kvm"] move scratchpad
  for_window [app_id="Qemu-system-x86_64"] move scratchpad

  # xwayland -- still needed for GTK/X11 applets (nm-applet, blueman). dunst
  # no longer needs it: swaync is Wayland-native, and satty replaced
  # flameshot, which used to be the other reason this stayed on.
  xwayland enable

  # AUTOSTART
  exec sway-autostart
''
