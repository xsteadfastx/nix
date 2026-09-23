{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;
  swayncClient = "${pkgs.unstable.swaynotificationcenter}/bin/swaync-client";

  # Nerd Font glyph from its codepoint, via JSON's \u escape.
  #
  # Two reasons this indirection exists:
  #  1. A literal glyph written straight into this file silently became an
  #     empty string once (waybar got `format: ""` -- no icon at all), so glyphs
  #     never appear literally here.
  #  2. JSON's \u takes exactly four hex digits, so codepoints above U+FFFF --
  #     which is most of the Material Design set -- have to be written as a
  #     UTF-16 surrogate pair. The pairs below were generated, not hand-rolled.
  #
  # Every codepoint here was checked against the built font's charset
  # (fc-query), which is why the icons work at all: this font only gained the
  # Font Awesome / Material ranges once `--complete` was passed to
  # font-patcher (see pkgs/jetbrainsmono-nerdfont-zero.nix).
  glyph = body: builtins.fromJSON ''"${body}"'';

  icons = {
    cpu = glyph ''\uF2DB''; # fa-microchip
    memory = glyph ''\uDB80\uDF5B''; # md-memory            (astral)
    disk = glyph ''\uDB80\uDECA''; # md-harddisk          (astral)
    wifi = glyph ''\uDB81\uDDA9''; # md-wifi              (astral)
    ethernet = glyph ''\uDB80\uDE00''; # md-ethernet          (astral)
    disconnected = glyph ''\uDB81\uDDAA''; # md-wifi_off          (astral)
    bell = glyph ''\uDB80\uDC9A''; # md-bell              (astral)
    clock = glyph ''\uDB82\uDD54''; # md-clock             (astral)
    volume = glyph ''\uDB81\uDD7E''; # md-volume_high       (astral)
    muted = glyph ''\uDB81\uDD81''; # md-volume_off        (astral)
    batteryEmpty = glyph ''\uF244''; # fa-battery-empty
    batteryQ1 = glyph ''\uF243''; # fa-battery-quarter
    batteryHalf = glyph ''\uF242''; # fa-battery-half
    batteryQ3 = glyph ''\uF241''; # fa-battery-three-quarters
    batteryFull = glyph ''\uF240''; # fa-battery-full
  };
in
lib.mkIf cfg.desktop {
  # The bar, replacing swaybar + bumblebee-status.
  #
  # Flat Dracula with icons. Powerline was built first and then dropped: with
  # Dracula's palette every second segment sat on the bar colour, so the row
  # read as irregular islands and a green "plugged" battery slab cut across it.
  # See style.css for the palette.
  #
  # `mode = "dock"` here is only a fallback: with `ipc = true` waybar asks
  # sway for the bar's initial configuration and creates its window with THAT
  # mode, so the real mode/hidden_state/modifier live in the `bar {}` block in
  # ../sway/config.nix (`mode hide` + `modifier Mod4` = hidden until Super is
  # held). `start_hidden` is deliberately absent -- sway owns that now.
  #
  # `ipc = true` is what makes the peek work: it subscribes waybar to sway's bar
  # state events and reveals it on `visible_by_modifier`. No `id` is set, so
  # waybar uses sway's default bar_id (bar-0), which is what sway assigns.
  #
  # systemd.enable = false, because sway launches waybar via `swaybar_command`
  # in that same `bar {}` block. Leaving the unit on would give TWO bars.
  #
  # NOTE: module definitions sit directly on the bar, NOT nested under a
  # `modules = { ... }` attr -- Home Manager removed that nesting and writing it
  # that way makes the whole system fail to evaluate.
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    systemd.enable = false; # sway owns the process; see the bar block in sway/config.nix
    style = ./style.css;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        mode = "dock"; # fallback only -- sway's bar config wins under ipc
        ipc = true;
        height = 30;

        modules-left = [
          "sway/workspaces"
          "sway/mode"
        ];

        # Mirrors the old bumblebee module order:
        #   cpu memory disk nic battery pipewire datetime
        # (nic -> network, pipewire -> wireplumber, datetime -> clock), then the
        # notification-centre button and the tray.
        modules-right = [
          "cpu"
          "memory"
          "disk"
          "network"
          "battery"
          "wireplumber"
          "clock"
          "custom/swaync"
          "tray"
        ];

        # ── Tray ────────────────────────────────────────────────────────────
        # The module swaybar never had: Waybar speaks StatusNotifierItem
        # properly, which is why blueman's tray icon ("its SNI properties are
        # unsupported", per ../sway/config.nix) could never render there. The
        # applets themselves are still launched from sway-autostart.
        tray = {
          icon-size = 18;
          spacing = 8;
        };

        # ── Notification centre ─────────────────────────────────────────────
        # -t toggles the swaync panel, -sw shows it.
        "custom/swaync" = {
          format = icons.bell;
          tooltip = false;
          on-click = "${swayncClient} -t -sw";
        };

        # ── Workspaces / mode ───────────────────────────────────────────────
        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{name}";
        };

        # Binding-mode indicator (the old bar's binding_mode colours).
        "sway/mode" = {
          format = "  {}";
        };

        # ── Right-hand modules ──────────────────────────────────────────────
        cpu = {
          interval = 5;
          format = " ${icons.cpu} {usage}%";
          tooltip = false;
        };

        memory = {
          interval = 5;
          format = " ${icons.memory} {percentage}%";
          tooltip-format = "{used} / {total} GiB";
        };

        disk = {
          interval = 30;
          path = "/";
          format = " ${icons.disk} {percentage_used}%";
          tooltip-format = "{used} / {total} GiB";
        };

        # bumblebee's nic module needed an exclude list (ip6tnl, veth, vir,
        # docker, br, lo, cni0, flannel.1, cali, vxlan.calico, w1nd50r) to hide
        # container/virtual interfaces. Waybar's network module follows the
        # default route, so that list is simply gone.
        network = {
          interval = 3;
          format-wifi = " ${icons.wifi} {essid} {signalStrength}%";
          format-ethernet = " ${icons.ethernet} {ifname}";
          format-disconnected = " ${icons.disconnected} offline";
          tooltip-format = "{ifname} via {gwaddr}";
        };

        # {icon} steps through format-icons by charge level.
        battery = {
          interval = 30;
          format = " {icon} {capacity}%";
          format-charging = " {icon} {capacity}%";
          format-icons = [
            icons.batteryEmpty
            icons.batteryQ1
            icons.batteryHalf
            icons.batteryQ3
            icons.batteryFull
          ];
          states = {
            warning = 30;
            critical = 15;
          };
        };

        wireplumber = {
          format = " ${icons.volume} {volume}%";
          format-muted = " ${icons.muted} muted";
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-scroll-up = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 1%+";
          on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-";
        };

        clock = {
          interval = 1;
          format = " ${icons.clock} {:%T %d/%m/%Y}";
          tooltip-format = "<tt>{calendar}</tt>";
        };
      };
    };
  };
}
