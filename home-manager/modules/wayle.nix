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

  # Per-module colours from the table the zellij bar shares: cpu peach, memory
  # sky, disk green, battery pink, clock overlay1.
  bar = import ../lib/statusbar.nix { inherit lib; };
  seg = name: ctp.hex bar.segments.${name}.color;

  # wayle's icon slot takes an icon-theme name, not a codepoint. These SVGs draw
  # the Nerd Font glyph as text, so the icon shape is the same character zellij
  # prints, while the button keeps wayle's coloured square (symbolic icons get
  # tinted by GTK, the fill colour is ignored).
  glyphIcon = name: ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
      <text x="8" y="13" font-family="Nerdwand Mono" font-size="14" text-anchor="middle">&#x${
        lib.toUpper (lib.toHexString bar.segments.${name}.glyph)
      };</text>
    </svg>
  '';

  iconName = name: "nfg-${name}-symbolic";
  wayle = "${pkgs.wayle}/bin/wayle";

  # battery has no single glyph (a list stepped by charge level), so it keeps
  # wayle's own icon.
  glyphSegments = [
    "cpu"
    "memory"
    "disk"
    "clock"
  ];

  palette = {
    bg = ctp.hex "base";
    surface = ctp.hex "surface0";
    elevated = ctp.hex "surface1";
    fg = ctp.hex "text";
    fg-muted = ctp.hex "overlay1";
    primary = ctp.hex config.catppuccin.accent;
    red = ctp.hex "red";
    yellow = ctp.hex "yellow";
    green = ctp.hex "green";
    blue = ctp.hex "blue";
  };
in
lib.mkIf cfg.desktop {
  # hicolor is the theme every icon lookup falls back to, so no theme selection.
  xdg.dataFile = lib.listToAttrs (
    map (
      name:
      lib.nameValuePair "icons/hicolor/scalable/actions/${iconName name}.svg" {
        text = glyphIcon name;
      }
    ) glyphSegments
  );

  # A switch swaps the config.toml symlink; the running shell does not notice,
  # so restart it when the file changes (wayle refuses a second instance, which
  # also means a manual test run is impossible while the service is up).
  systemd.user.services.wayle.Unit.X-Restart-Triggers = lib.mkForce [
    "${config.xdg.configFile."wayle/config.toml".source}"
  ];

  services.wayle = {
    enable = true;
    autoInstallDependencies = false;

    settings = {
      bar = {
        location = "top";
        # no height option: thickness is padding + button size
        scale = 0.8;
        padding = 0.1;
        button-label-size = 0.9;
        layout = [
          {
            monitor = "*";
            left = [ "niri-workspaces" ];
            center = [ ];
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

        cpu = {
          icon-name = iconName "cpu";
          icon-bg-color = seg "cpu";
        };
        ram = {
          icon-name = iconName "memory";
          icon-bg-color = seg "memory";
        };
        storage = {
          icon-name = iconName "disk";
          icon-bg-color = seg "disk";
        };
        battery.icon-bg-color = seg "battery";
        clock = {
          format = "%T %d/%m/%Y";
          icon-name = iconName "clock";
          icon-bg-color = ctp.hex "surface1";
          label-color = seg "clock";
        };

        # wayle steps three icons by level, and its lowest is the *plain*
        # speaker (no waves) -- at 33% that reads as "no sound". One icon for
        # all levels, with ld-volume-x for mute, is what the old bar showed.
        # Ascending, like the level: one wave below 50%, two above. wayle's own
        # default puts the *plain* speaker (no waves) first, which at low volume
        # reads as "no sound"; ld-volume-x is mute.
        volume = {
          level-icons = [
            "ld-volume-1-symbolic"
            "ld-volume-2-symbolic"
          ];
          # click the icon = mute, right-click = device/app sliders,
          # wheel = 5% per notch
          left-click = "${wayle} audio output-mute";
          right-click = "dropdown:audio";
          scroll-up = "${wayle} audio output-volume +5";
          scroll-down = "${wayle} audio output-volume -5";
        };
        network.icon-bg-color = ctp.hex "surface1";
        bluetooth.icon-bg-color = ctp.hex "surface1";
        notifications.icon-bg-color = ctp.hex "surface1";

        "niri-workspaces" = {
          display-mode = "none";
          app-icons-show = true;
          app-icons-dedupe = false;
          # not in wayle's built-in app_id globs
          app-icon-map = {
            "*fluffychat*" = "si-element-symbolic";
            # user globs are case-SENSITIVE (glob::matches, no lowercasing), so
            # "*meshy*" missed "…Meshy" -- match the lowercase part instead, and
            # it also beats wayle's builtin "*code*" glob that matches "codeberg"
            "*codeberg*" = "ld-app-window-symbolic";
          };
        };
      };
    };
  };
}
