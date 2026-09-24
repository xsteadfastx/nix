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
    music = glyph ''\uDB81\uDF5A''; # md-music             (astral)
    pause = glyph ''\uDB80\uDFE4''; # md-pause             (astral)
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
  # `mode = "dock"` is the real mode now: always visible, standard systemd-run
  # waybar like everyone else's setup, not sway hide/reveal-managing it via
  # `swaybar_command` + bar IPC (that used to live in ../sway/config.nix's
  # `bar {}` block -- removed, along with the repeated layer-surface
  # show/hide churn every Mod4 press caused). No `ipc` setting: that was only
  # for asking sway for the hide/reveal bar_state_update, which nothing needs
  # anymore -- the `sway/workspaces` and `sway/mode` modules below have their
  # own separate IPC connection to sway and don't need it either.
  #
  # NOTE: module definitions sit directly on the bar, NOT nested under a
  # `modules = { ... }` attr -- Home Manager removed that nesting and writing it
  # that way makes the whole system fail to evaluate.
  # The `mpris` module below attaches to the `playerctld` player, which is a
  # D-Bus name rather than a real player: with no daemon owning it waybar has
  # nothing to show and hides the module, however happily chromium (or anything
  # else) is playing. Nothing in this repo ever installed playerctl, so nothing
  # ever owned that name. Home Manager's module for it also puts `playerctl`
  # into home.packages, whose `share/dbus-1/services` entry is the other way
  # the session bus can get the daemon started.
  services.playerctld.enable = true;

  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    systemd.enable = true;
    style = ./style.css;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        mode = "dock";
        height = 30;

        modules-left = [
          "sway/workspaces"
          "sway/mode"
        ];

        # MPRIS "now playing" -- centered since it's the one module that's
        # empty most of the time (waybar hides a module with nothing to show
        # rather than drawing a blank one), so it doesn't crowd either
        # cluster. play/pause on click, skip on right-click -- waybar's builtin
        # click actions go through the libplayerctl it links at build time, not
        # a shell-out, so the only thing `services.playerctld` above has to
        # supply is the daemon those actions are sent to.
        modules-center = [ "mpris" ];

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

        # ── Now playing ─────────────────────────────────────────────────────
        # Waybar's default mpris format is "{player} ({status}) {dynamic}" --
        # a bare player name, no icon. Note + track, and the paused state swaps
        # the note for a pause glyph and italicises the title.
        mpris = {
          format = " ${icons.music} {dynamic}";
          format-paused = " ${icons.pause} <i>{dynamic}</i>";
          # Measured against the 1360px output: only ~470px sits between the
          # workspace buttons and the right-hand cluster (which is ~735px on its
          # own), while an unchecked YouTube title runs to ~670px and clips that
          # cluster. Bounding the individual tags rather than the whole label is
          # what keeps the elapsed time: 26 title + 14 artist + the trailing
          # "[mm:ss/mm:ss]" renders at ~355px, leaving ~115px of slack for the
          # tray to grow into.
          title-len = 26;
          artist-len = 14;
          dynamic-len = 58;
          # Position/length are truncated LAST here, not first: the default
          # importance order (title, artist, album, position, length) sacrifices
          # the elapsed time the moment a title is long -- with a plain dynamic
          # cap, that is what swallowed "[28:54/40:06]". Earlier entry = cut
          # later, so the artist absorbs the squeeze instead. Whatever still
          # overflows gets a "…"; the tooltip ignores these limits, so hovering
          # still shows the full title.
          dynamic-importance-order = [
            "position"
            "length"
            "title"
            "artist"
            "album"
          ];
          # Without this the module only re-reads the player on events
          # (metadata/play/pause), so the elapsed time sits frozen in the bar.
          interval = 1;
        };

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
