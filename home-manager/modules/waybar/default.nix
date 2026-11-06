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

  # Glyphs and the colour/threshold of every metric both bars show -- see
  # home-manager/lib/statusbar.nix. This module renders them into waybar's
  # dialect (config JSON + CSS); the zellij module renders the same values into
  # zjstatus', which is what keeps the two bars looking the same.
  statusbar = import ../../lib/statusbar.nix { inherit lib; };

  # Glyphs waybar has and the zellij bar does not (network, volume):
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

  # The palette is the Catppuccin waybar port's @define-color file, *inlined*:
  # waybar's GTK css parser did not resolve `@import "/nix/store/…"`, so every
  # colour was undefined and the bar rendered unstyled (2026-11-02). style.css
  # and the generated metric rules then use the Catppuccin names (@base,
  # @mauve, …).
  styleCss =
    builtins.readFile "${config.catppuccin.sources.waybar}/${config.catppuccin.flavor}.css"
    + "\n"
    + builtins.readFile ./style.css
    + "\n"
    # Appended so they win over the shared `color: @text` in style.css's
    # module block (same specificity, source order decides).
    + lib.concatStringsSep "\n" (lib.mapAttrsToList segmentCss statusbar.segments)
    + "\n";

  # `#cpu { color: @peach; }` plus one rule per state. `classes` is waybar's own
  # class name where it differs from the state name (a plugged battery is
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
  # Flat bar with icons. Powerline was built first and then dropped: every
  # second segment sat on the bar colour, so the row
  # read as irregular islands and a green "plugged" battery slab cut across it.
  # See home-manager/lib/statusbar.nix for the segment colours; style.css
  # holds the layout and the waybar-only colours.
  #
  # `mode = "dock"` is the real mode now: always visible, a normal systemd user
  # service, not compositor-managed via `bar {}` + IPC.
  #
  # NOTE: module definitions sit directly on the bar, NOT nested under a
  # `modules = { ... }` attr -- Home Manager removed that nesting and writing it
  # that way makes the whole system fail to evaluate.
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

  # The taskbar module below is a shared object waybar dlopen()s at runtime, so
  # the store path has to survive garbage collection on its own.
  home.packages = [ pkgs.niri-taskbar ];

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

        modules-left = [ "cffi/niri-taskbar" ];

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

        # ── Taskbar ─────────────────────────────────────────────────────────
        # One button per window, ordered by niri's layout -- and only the
        # windows on this bar's own output, while their workspace is the one
        # that output shows (pkgs/niri-taskbar/local-fixes.patch). waybar's own
        # wlr/taskbar cannot do this: wlr-foreign-toplevel-management defines no
        # ordering (niri discussion #549), so buttons arrive in whatever order
        # the compositor sent the toplevels. This CFFI module talks to niri's
        # IPC instead and handles clicks itself.
        "cffi/niri-taskbar" = {
          module_path = "${pkgs.niri-taskbar}/lib/libniri_taskbar.so";
        };

        # ── Tray ────────────────────────────────────────────────────────────
        # Waybar speaks StatusNotifierItem, which is what renders the applets'
        # tray icons. The applets themselves are systemd user units
        # (../applets.nix).
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
