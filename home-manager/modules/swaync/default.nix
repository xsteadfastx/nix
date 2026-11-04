{
  config,
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  # The Catppuccin port's stylesheet (catppuccin.swaync is off, see
  # ../catppuccin.nix), with the session font instead of its hardcoded
  # "Ubuntu Nerd Font" -- size stays at the port's 14px: 12px Lilex reads thin
  # at ~92 DPI -- plus a colour for toggle buttons that are on, which the port
  # leaves empty. Same blue as its DND switch.
  inherit (config.catppuccin) flavor;
  ctp = import ../../../lib/palette.nix {
    inherit lib;
    inherit (config) catppuccin;
  };
  style = pkgs.runCommand "swaync-catppuccin-${flavor}.css" { } ''
    sed 's/"Ubuntu Nerd Font"/"Lilex Nerd Font"/' \
      ${config.catppuccin.sources.swaync}/${flavor}.css > $out
    # an upstream rename would make the substitution miss silently
    grep -q '"Lilex Nerd Font"' $out || { echo "font not substituted"; exit 1; }
    cat >> $out <<'EOF'

    .widget-buttons-grid flowboxchild > button.toggle:checked {
      color: ${ctp.hex "blue"};
    }
    EOF
  '';

  # Quick-settings glyphs, written as codepoints like the bars' (see
  # ../../lib/statusbar.nix for why).
  statusbar = import ../../lib/statusbar.nix { inherit lib; };
  glyph = cp: statusbar.char (lib.fromHexString cp);

  nmcli = "${pkgs.networkmanager}/bin/nmcli";
  bluetoothctl = "${pkgs.bluez}/bin/bluetoothctl";
  grep = "${pkgs.gnugrep}/bin/grep";
  swaync-client = "${pkgs.unstable.swaynotificationcenter}/bin/swaync-client";

  # swaync splits a button's command into argv itself -- no shell -- so
  # anything with $(...), && or ; has to be a script. Toggle buttons get the
  # new state in $SWAYNC_TOGGLE_STATE; the update-command re-reads the real one
  # each time the panel opens, so a switch made elsewhere (nm-applet, blueman)
  # is reflected.
  sh = name: text: "${pkgs.writeShellScript "swaync-${name}" text}";
  onOff = ''"$([ "$SWAYNC_TOGGLE_STATE" = true ] && echo on || echo off)"'';

in
lib.mkIf cfg.desktop {
  # The notification daemon, replacing dunst. dunst is X11 and ran under
  # XWayland; swaync is Wayland-native GTK4, so notifications are real
  # layer-shell surfaces and there is a control centre (scrollback, DND,
  # volume/brightness sliders) rather than popups only.
  #
  # The Home Manager module already ships the systemd user unit (Type=dbus,
  # BusName=org.freedesktop.Notifications, WantedBy = wayland.systemd.target,
  # which is graphical-session.target here), so nothing execs it from a session
  # script and no autostart entry is needed.
  #
  # Style: the Catppuccin port's stylesheet with two patches (`style` above).
  # The 642-line hand layout that used to live beside this module is gone --
  # see git history if the upstream layout ever needs more than that.
  #
  # NOTE: home-manager's services.swaync does NOT pull in libnotify, but the
  # brightness/volume bindings in ../niri/config.nix call notify-send. Without
  # the explicit package below the daemon would run and those OSDs would
  # silently do nothing.
  services.swaync = {
    enable = true;
    inherit style;
    package = pkgs.unstable.swaynotificationcenter;

    # Ported from the old dunstrc where an equivalent exists. dunst's
    # `follow = mouse` has no swaync counterpart -- there is no `monitor` key in
    # swaync's configSchema, and layer-shell already places notifications on the
    # focused output, which is what `follow = mouse` was approximating.
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "top";
      control-center-layer = "top";
      layer-shell = true;
      # Must be "user", not "application". swaync's own schema says it:
      #   "Which GTK priority to use when loading the default and user CSS
      #    files. Pick \"user\" to override XDG_CONFIG_HOME/gtk-4.0/gtk.css"
      # That file is where this repo imports the Catppuccin GTK theme, and that
      # theme paints `.background { background-color: #1e1e2e }` -- on a *user*
      # provider, which beats swaync's application-level one. Result: the
      # notification layer surface (full monitor height, mostly empty) rendered
      # as a solid #1e1e2e slab down to the bottom of the screen. Measured the
      # slab pixels: exactly #1e1e2e, i.e. the theme's colour.
      # The transparent `.background` rule in style.css only takes effect once
      # this priority is raised.
      cssPriority = "user";

      timeout = 10; # dunstrc [urgency_normal] timeout
      timeout-low = 5; # dunstrc [urgency_low] timeout
      timeout-critical = 0; # critical never auto-dismisses, as before

      notification-icon-size = 64; # dunstrc max_icon_size
      notification-body-image-height = 100;
      notification-body-image-width = 200;
      notification-inline-replies = true; # reply to a chat from the popup
      notification-2fa-action = true;

      hide-on-clear = true;
      hide-on-action = false;

      control-center-margin-top = 10;
      control-center-margin-right = 10;
      control-center-margin-bottom = 10;
      control-center-margin-left = 10;

      # swaync's default set plus "now playing" (moved out of waybar), volume
      # and quick settings. Setting `widgets` replaces the default list, so the
      # stock entries are repeated.
      widgets = [
        "inhibitors"
        "title"
        "dnd"
        "mpris"
        "volume"
        "buttons-grid"
        "notifications"
      ];
      widget-config = {
        # playerctld (for the niri media keys) registers as an MPRIS player that
        # mirrors the active one, so every track showed up twice in the carousel.
        mpris.blacklist = [ "playerctld" ];
        # The per-app sliders are the point: otherwise only pavucontrol has them.
        volume = {
          label = glyph "F057E"; # md-volume_high
          show-per-app = true;
          show-per-app-label = true;
        };
        buttons-grid = {
          buttons-per-row = 3;
          actions = [
            {
              label = glyph "F05A9"; # md-wifi
              type = "toggle";
              command = sh "wifi" "${nmcli} radio wifi ${onOff}";
              update-command = sh "wifi-state" ''[ "$(${nmcli} radio wifi)" = enabled ] && echo true || echo false'';
            }
            {
              label = glyph "F00AF"; # md-bluetooth
              type = "toggle";
              command = sh "bluetooth" "${bluetoothctl} power ${onOff}";
              update-command = sh "bluetooth-state" "${bluetoothctl} show | ${grep} -q 'Powered: yes' && echo true || echo false";
            }
            {
              label = glyph "F033E"; # md-lock
              command = sh "lock" "${swaync-client} -cp; exec ${pkgs.swaylock}/bin/swaylock -f";
            }
          ];
        };
      };
    };
  };

  # notify-send, for the brightness/volume bindings in ../niri/config.nix.
  home.packages = [ pkgs.libnotify ];
}
