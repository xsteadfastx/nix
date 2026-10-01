{
  config,
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;
  swayncClient = "${pkgs.unstable.swaynotificationcenter}/bin/swaync-client";

  # Glyphs, the Dracula palette, and the colour/threshold of every metric both
  # bars show -- see home-manager/lib/statusbar.nix. This module renders them
  # into waybar's dialect (config JSON + CSS); the zellij module renders the
  # same values into zjstatus' (layout KDL + the metrics script), which is what
  # keeps the two bars looking the same.
  statusbar = import ../../lib/statusbar.nix { inherit lib; };

  # Glyphs waybar has and the zellij bar does not (network, volume, mpris):
  # segments of its own, so their glyphs live here. Codepoints written as hex
  # strings, same as the shared ones -- see statusbar.nix for why (nixfmt) and
  # for the font-charset check every codepoint here went through.
  glyph = lib.fromHexString;
  icons = lib.mapAttrs (_: statusbar.char) (
    statusbar.icons
    // {
      wifi = glyph "F05A9"; # md-wifi
      ethernet = glyph "F0200"; # md-ethernet
      disconnected = glyph "F05AA"; # md-wifi_off
      vpn = glyph "F0582"; # md-vpn
      bell = glyph "F009A"; # md-bell
      volume = glyph "F057E"; # md-volume_high
      muted = glyph "F0581"; # md-volume_off
      music = glyph "F075A"; # md-music
      pause = glyph "F03E4"; # md-pause
    }
  );

  # Battery label: one plain format and one carrying the AC word, applied per
  # status class. Same word as the zellij bar's metrics script, from the same
  # entry in statusbar.nix.
  batteryFormats = {
    format = " {icon} {capacity}%";
    format-full = " {icon} {capacity}%";
  }
  // lib.listToAttrs (
    map (
      class: lib.nameValuePair "format-${class}" " {icon} ${statusbar.segments.battery.word} {capacity}%"
    ) statusbar.segments.battery.wordClasses
  );

  # style.css holds the layout and the waybar-only colours; the palette and the
  # metric colour rules are generated from the same data the zellij bar renders
  # from, so the two cannot drift. Prepended, not appended: @define-color has to
  # precede its uses (GTK resolves at parse time).
  styleCss = pkgs.writeText "waybar-style.css" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: hex: "@define-color ${name} ${hex};") statusbar.palette
    )
    + "\n"
    + builtins.readFile ./style.css
    + "\n"
    # Appended so they win over the shared `color: @foreground` in style.css's
    # module block (same specificity, source order decides).
    + lib.concatStringsSep "\n" (lib.mapAttrsToList segmentCss statusbar.segments)
    + "\n"
  );

  # `#cpu { color: @orange; }` plus one rule per state. `classes` is waybar's
  # own class name where it differs from the state name (a plugged battery is
  # `#battery.charging` / `.plugged` / `.full`).
  segmentCss =
    _: segment:
    lib.concatStringsSep "\n" (
      [ "#${segment.waybar} {\n    color: @${segment.color};\n}" ]
      ++ map (
        state:
        let
          classes = state.classes or [ state.name ];
        in
        "${
          lib.concatMapStringsSep ",\n" (class: "#${segment.waybar}.${class}") classes
        } {\n    color: @${state.color};\n}"
      ) (segment.states or [ ])
    );
in
lib.mkIf cfg.desktop {
  # The bar, replacing swaybar + bumblebee-status.
  #
  # Flat Dracula with icons. Powerline was built first and then dropped: with
  # Dracula's palette every second segment sat on the bar colour, so the row
  # read as irregular islands and a green "plugged" battery slab cut across it.
  # See home-manager/lib/statusbar.nix for the palette and the segment
  # colours; style.css holds the layout and the waybar-only colours.
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

  # Waybar does not heal itself, so systemd does it:
  #
  # - Restart on config change, never reload. Home Manager's default sends
  #   SIGUSR2 on a switch, and waybar's in-process reload leaks state
  #   (duplicate tray hosts, "already registered").
  # - Bound to wireplumber. The `wireplumber` module never reconnects after
  #   the audio stack restarts (or is killed -- `pkill pi` matches pipewire),
  #   and sits at 0% forever. BindsTo stops waybar with it; Upholds on the
  #   session target starts it straight back, which in turn pulls the audio
  #   stack back up.
  # ponytail: if wireplumber cannot start at all the bar is gone too; drop
  # BindsTo for Wants if that ever bites.
  systemd.user.services.waybar.Unit = {
    X-Reload-Triggers = lib.mkForce [ ];
    X-Restart-Triggers = [
      "${config.xdg.configFile."waybar/config".source}"
      "${config.xdg.configFile."waybar/style.css".source}"
    ];
    BindsTo = [ "wireplumber.service" ];
    After = [ "wireplumber.service" ];
  };
  systemd.user.targets.sway-session.Unit.Upholds = [ "waybar.service" ];

  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    systemd.enable = true;
    style = styleCss;

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

        # The old bumblebee bar's modules -- nic -> network, pipewire ->
        # wireplumber, datetime -> clock -- in our own order, then the
        # notification-centre button and the tray.
        modules-right = [
          "cpu"
          "memory"
          "disk"
          "battery"
          "wireplumber"
          "network#wifi"
          "network#nic"
          "network#tailscale"
          "network#wobcom"
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
          # what keeps the elapsed time. 26 title + 14 artist rendered at
          # ~355px (~6px/char); the tailscale + wobcom indicators then took
          # ~135px of the ~115px slack. 14 + 6 sheds ~120px: ~235px, ~100px
          # slack with both VPNs up.
          title-len = 14;
          artist-len = 6;
          dynamic-len = 36;
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
        # applets themselves are systemd user units (../sway/applets.nix).
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
          # waybar only emits a state class when `states` exists
          # (src/ALabel.cpp getState), so without this the segment never
          # changes colour; the classes' colours are generated into style.css
          # from the same thresholds.
          states = statusbar.statesFor "disk";
        };

        # bumblebee's nic module needed an exclude list (ip6tnl, veth, vir,
        # docker, br, lo, cni0, flannel.1, cali, vxlan.calico, w1nd50r) to hide
        # container/virtual interfaces.
        #
        # One module per physical interface, each pinned with `interface`.
        # Unpinned, the module follows the default route and sticks on
        # "offline" once that route bounces (resume, dock events) while ppp0 /
        # tailscale0 are up -- the 2026-09-24 manual-restart. Pinned, it
        # tracks its own interface through drops. `#network` CSS still
        # applies: `network#wifi` is `#network.wifi`.
        "network#wifi" = {
          interface = "wlp*";
          interval = 3;
          format-wifi = " ${icons.wifi} {essid} {signalStrength}%";
          format-disconnected = " ${icons.disconnected} offline";
          tooltip-format = "{ifname} via {gwaddr}";
        };
        # Wired (dock NIC): hidden unless it is actually up -- an empty format
        # makes waybar hide the module.
        "network#nic" = {
          interface = "enp*";
          interval = 3;
          format-ethernet = " ${icons.ethernet} {ifname}";
          format-linked = "";
          format-disconnected = "";
          tooltip-format = "{ifname} via {gwaddr}";
        };
        # Tailscale: shown while tailscale0 holds an address. `tailscale down`
        # keeps the tun but drops its IPs -- "linked", hidden like "down".
        "network#tailscale" = {
          interface = "tailscale0";
          interval = 3;
          format-ethernet = " ${icons.vpn} ts";
          format-linked = "";
          format-disconnected = "";
          tooltip-format = "{ifname} {ipaddr}";
        };
        # wobcom VPN (openfortivpn -> pppd -> ppp0, started by `wobcom-vpn`).
        # pppd removes ppp0 on hangup, so the module is only there while the
        # tunnel is up -- and vanishing is the hint that it dropped.
        "network#wobcom" = {
          interface = "ppp0";
          interval = 3;
          format-ethernet = " ${icons.vpn} wobcom";
          format-linked = "";
          format-disconnected = "";
          tooltip-format = "{ifname} {ipaddr}";
        };

        # {icon} steps through format-icons by charge level. The formats come
        # from batteryFormats above: waybar swaps the whole format per status
        # class, and the classes that mean "on mains" also print the AC word the
        # zellij bar prints (both from home-manager/lib/statusbar.nix).
        battery = {
          interval = 30;
          format-icons = map statusbar.char statusbar.segments.battery.icons;
          states = statusbar.statesFor "battery";
        }
        // batteryFormats;

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
