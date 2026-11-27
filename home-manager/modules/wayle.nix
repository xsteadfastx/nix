{
  config,
  lib,
  nixosConfig,
  pkgs,
  ...
}:
# Wayle: bar, notification daemon, OSD and tray in one process. No taskbar — see
# niri-workspaces; the old one lives in git history (waybar + pkgs/niri-taskbar).
let
  cfg = nixosConfig.features;

  ctp = import ../../lib/palette.nix {
    inherit lib;
    inherit (config) catppuccin;
  };

  # Colours come from the table the zellij bar shares: cpu peach, memory sky,
  # disk green, battery pink, clock overlay1. So does the split: measurements
  # get a coloured chip, tools (network, bluetooth, clock, notifications) stay
  # neutral -- wayle has no per-state colour fields, only per-state icons, so
  # "connected"/"unread"/"DND" is shown by the icon, not by colour.
  bar = import ../lib/statusbar.nix { inherit lib; };
  seg = name: ctp.hex bar.segments.${name}.color;

  # wayle's icon slot takes an icon-theme name, not a codepoint. These SVGs draw
  # the Nerd Font glyph as text, so the icon shape is the same character zellij
  # prints, while the button keeps wayle's coloured square (symbolic icons get
  # tinted by GTK, the fill colour is ignored).
  # 20x20 box, 15px glyph, and x=7 rather than the centre: these glyphs carry
  # their ink to the right of the advance width, so centring at 10 clipped the
  # right edge (checked by rasterising every icon and asserting no edge ink).
  glyphSvg = cp: ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
      <text x="7" y="14.4" font-family="JetBrainsMono Nerd Font" font-size="15" text-anchor="middle">&#x${lib.toUpper (lib.toHexString cp)};</text>
    </svg>
  '';
  glyphIcon = name: glyphSvg bar.segments.${name}.glyph;
  iconFile =
    name: text:
    lib.nameValuePair "icons/hicolor/scalable/actions/${iconName name}.svg" {
      inherit text;
    };

  iconName = name: "nfg-${name}-symbolic";
  wayle = "${pkgs.wayle}/bin/wayle";

  # Stepped by charge level, so the five battery glyphs are named separately.
  glyphSegments = [
    "cpu"
    "memory"
    "disk"
    "clock"
  ];

  # The tool modules ship Lucide/Cosmic icons; these draw the Nerd Font
  # equivalent instead, so the whole bar is one glyph family (and matches the
  # zellij bar). Codepoints checked against the built font's charset.
  # app_id globs -> bar glyph. Read by niri-workspaces (the cluster) and
  # window-title (the focused window); both match window class by glob.
  appIcons = {
    "*librewolf*" = toolIcon "web";
    "*ghostty*" = toolIcon "console";
    "*fluffychat*" = toolIcon "chat";
    # Globs are case-sensitive (glob::matches, no lowercasing), and a user entry
    # beats wayle's builtin "*code*" glob. Not in wayle's builtin app_id globs
    # either (upstream #228 would make the icon theme the source).
    "*codeberg*" = "ld-app-window-symbolic";
  };

  toolGlyphs = {
    # md's wifi-strength-* glyphs are filled wedges, nothing like a wifi arc;
    # md-wifi is the arc. Signal level is not drawn, only connected/off.
    wifi = "F05A9"; # md-wifi
    wifiOff = "F05AA"; # md-wifi-off
    ethernet = "F0200"; # md-ethernet
    bluetooth = "F00AF"; # md-bluetooth
    bluetoothOff = "F00B2"; # md-bluetooth-off
    volumeLow = "F027"; # fa-volume-low
    volumeHigh = "F028"; # fa-volume-high
    volumeMuted = "F075F"; # md-volume-mute (speaker with an x)
    web = "F059F"; # md-web
    console = "F018D"; # md-console
    chat = "F0B79"; # md-chat
    bell = "F009A"; # md-bell
    bellUnread = "F116B"; # md-bell-badge
    bellOff = "F009B"; # md-bell-off
  };
  toolIcon = iconName;

  batteryGlyphs = [
    "batteryEmpty"
    "batteryQuarter"
    "batteryHalf"
    "batteryThreeQuarters"
    "batteryFull"
  ];
  batteryIcons = map iconName batteryGlyphs;

  # wayle derives --bg-base/--bg-surface/--bg-elevated from these three, and its
  # own theme steps them crust -> mantle -> base. Ours sat one rung higher
  # (base -> surface0 -> surface1), which painted the bar a mid grey and made
  # everything look washed out.
  palette = {
    bg = ctp.hex "crust";
    surface = ctp.hex "mantle";
    elevated = ctp.hex "base";
    fg = ctp.hex "text";
    fg-muted = ctp.hex "subtext0";
    primary = ctp.hex config.catppuccin.accent;
    red = ctp.hex "red";
    yellow = ctp.hex "yellow";
    green = ctp.hex "green";
    blue = ctp.hex "blue";
  };
in
{
  options.wayleBarMonitor = lib.mkOption {
    type = lib.types.str;
    default = "*";
    example = "eDP-1";
    description = ''
      Connector the wayle bar draws on, or "*" for every monitor. wayle has no
      "primary output": a layout names one connector, and outputs without a
      layout get no bar.
    '';
  };

  config = lib.mkIf cfg.desktop {
    # hicolor is the theme every icon lookup falls back to, so no theme selection.
    xdg.dataFile =
      lib.listToAttrs (
        map (name: iconFile name (glyphIcon name)) glyphSegments
        ++ map (name: iconFile name (glyphSvg bar.icons.${name})) batteryGlyphs
      )
      // lib.mapAttrs' (name: cp: iconFile name (glyphSvg (lib.fromHexString cp))) toolGlyphs;

    # A switch swaps the config.toml symlink; the running shell does not notice,
    # so restart it when the file changes (wayle refuses a second instance, which
    # also means a manual test run is impossible while the service is up).
    systemd.user.services.wayle.Unit.X-Restart-Triggers = lib.mkForce [
      "${config.xdg.configFile."wayle/config.toml".source}"
    ];

    # wayle hands the focused workspace's button a `.focused` class and ships no
    # rule for it; with monitor-specific = false every output has an active
    # workspace, so the accent fill/underline marks three buttons and says
    # nothing. Keep the accent for the one that has focus. `styles/` is wayle's
    # own override hook: compiled by grass and hot-reloaded on change.
    xdg.configFile."wayle/styles/index.scss" = {
      force = true;
      text = ''
        .workspaces.niri .workspace.active:not(.focused) .workspace-icon {
          color: var(--ws-occupied-color);
        }
        .workspaces.niri .workspace.active:not(.focused).indicator-underline {
          background-image: none;
        }
      '';
    };

    services.wayle = {
      enable = true;
      autoInstallDependencies = false;

      settings = {
        bar = {
          location = "top";
          # no height option: thickness is padding + button size
          scale = 1.0;
          padding = 0.1;
          # No slab at all: the bar paints nothing, so only the module pills
          # float over the content. inset-edge keeps them off the screen edge.
          background-opacity = 0;
          inset-edge = 0.2;
          inset-ends = 0.5;
          button-label-size = 0.9;
          layout = [
            {
              monitor = config.wayleBarMonitor;
              # Every running window in the bar (grouped by workspace, click
              # jumps to it) and the focused window's title in the middle --
              # the arrangement both reference setups use.
              left = [
                "niri-workspaces"
                "media"
              ];
              center = [ "window-title" ];
              right = [
                "cpu"
                "ram"
                "storage"
                "battery"
                "volume"
                "network"
                "bluetooth"
                "clock"
                "notifications"
                "systray"
              ];
            }
          ];
        };

        styling.palette = palette;

        modules = {
          # wayle draws its own icon set (SVG), zellij Nerd-Font glyphs -- the two
          # cannot be the same character. Colours come from the shared table.
          storage.mount-point = "/";

          # Peach chip, first in the right group: cpu before memory, disk, battery,
          # clock -- the old waybar order.
          cpu = {
            icon-name = iconName "cpu";
            icon-bg-color = seg "cpu";
            label-color = seg "cpu";
          };

          # Icon only, value as colour: normal state keeps the module colour, the
          # thresholds turn it yellow then red. No number to read, no width spent.
          ram = {
            icon-name = iconName "memory";
            icon-bg-color = seg "memory";
            label-color = seg "memory";
          };
          # Firefox (YouTube) and mpv both show up on the MPRIS bus, so the
          # centre slot is now-playing instead of empty.
          media = {
            format = "{{ title }}";
            label-max-length = 30;
            icon-bg-color = ctp.hex "blue";
            label-color = ctp.hex "blue";
          };

          storage = {
            icon-name = iconName "disk";
            icon-bg-color = seg "disk";
            label-color = seg "disk";
          };

          battery = {
            icon-bg-color = seg "battery";
            label-color = seg "battery";
            level-icons = batteryIcons;
            charging-icon = iconName "batteryFull";
            alert-icon = iconName "batteryEmpty";
          };

          clock = {
            format = "%T %d/%m/%Y";
            icon-name = iconName "clock";
            icon-bg-color = ctp.hex "surface0";
            icon-color = seg "clock";
            label-color = seg "clock";
          };

          # wayle steps three icons by level, and its lowest is the *plain*
          # speaker (no waves) -- at 33% that reads as "no sound". One icon for
          # all levels, with ld-volume-x for mute, is what the old bar showed.
          # Ascending, like the level: one wave below 50%, two above. wayle's own
          # default puts the *plain* speaker (no waves) first, which at low volume
          # reads as "no sound"; ld-volume-x is mute.
          volume = {
            icon-bg-color = ctp.hex "red";
            label-color = ctp.hex "red";
            level-icons = map toolIcon [
              "volumeLow"
              "volumeHigh"
            ];
            icon-muted = toolIcon "volumeMuted";
            # click the icon = mute, right-click = device/app sliders,
            # wheel = 5% per notch
            left-click = "${wayle} audio output-mute";
            right-click = "dropdown:audio";
            scroll-up = "${wayle} audio output-volume +5";
            scroll-down = "${wayle} audio output-volume -5";
          };

          network = {
            icon-bg-color = ctp.hex "surface0";
            icon-color = ctp.hex "subtext0";
            wifi-connected-icon = toolIcon "wifi";
            wifi-acquiring-icon = toolIcon "wifi";
            wifi-offline-icon = toolIcon "wifiOff";
            wifi-disabled-icon = toolIcon "wifiOff";
            wifi-signal-icons = map toolIcon [
              "wifi"
              "wifi"
              "wifi"
              "wifi"
            ];
            wired-connected-icon = toolIcon "ethernet";
            wired-disconnected-icon = toolIcon "ethernet";
          };

          bluetooth = {
            icon-bg-color = ctp.hex "surface0";
            icon-color = ctp.hex "subtext0";
            connected-icon = toolIcon "bluetooth";
            disconnected-icon = toolIcon "bluetooth";
            disabled-icon = toolIcon "bluetoothOff";
            searching-icon = toolIcon "bluetooth";
          };

          # Popups go to the active output: wayle is patched (overlays/wayle/)
          # so the default popup-monitor "primary" sets no monitor and niri
          # places each popup. Unpatched, "primary" meant the
          # first GDK monitor, fixed at shell start. Check with
          # `notify-send a b; niri msg layers`.
          notifications = {
            icon-bg-color = ctp.hex "surface0";
            icon-color = ctp.hex "subtext0";
            icon-name = toolIcon "bell";
            icon-unread = toolIcon "bellUnread";
            icon-dnd = toolIcon "bellOff";
          };

          "niri-workspaces" = {
            display-mode = "none";
            app-icons-show = true;
            # One icon per window (not per app_id), and keep five workspace
            # buttons on screen instead of only the occupied ones -- that is what
            # shows every running window in the bar.
            app-icons-dedupe = false;
            min-workspace-count = 5;
            # default true = only this output's workspaces, so a window on
            # another monitor never appears in the bar
            monitor-specific = false;
            # not in wayle's built-in app_id globs
            # wayle never tries the app_id itself as an icon name: it checks this
            # map, then a builtin table of 199 common apps, then draws one generic
            # window glyph. Naming the icon here is the only lever (upstream #228
            # "Use system icon theme" would make it automatic).
            # Silhouettes from the bar's own glyph set, not the apps' colourful
            # logos: the pills then match the rest of the bar. wayle never tries
            # the app_id itself as an icon name (upstream #228), so each app that
            # should not fall back to the window glyph is named here.
            app-icons-fallback = "ld-app-window-symbolic";
            app-icon-map = appIcons;
            # Every output's *active* workspace is filled with active-color, so
            # three monitors painted three accent slabs; an underline marks them
            # without the flood. wayle has no per-window styling either -- it puts
            # a `focused` class on the button, with no rule behind it -- so the
            # focused window is named by the window-title module below.
            active-indicator = "underline";
            active-color = ctp.hex "mauve";
          };

          # The window that has focus: its app icon (same map as the cluster, so a
          # mauve square on the left of the title matches one of the quiet icons)
          # and its title.
          "window-title" = {
            icon-mappings = appIcons;
            icon-bg-color = ctp.hex "mauve";
            label-color = ctp.hex "text";
          };
        };
      };
    };
  };
}
