{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;
in
lib.mkIf cfg.desktop {
  # The notification daemon, replacing dunst. dunst is X11 and ran under
  # XWayland; swaync is Wayland-native GTK4, so notifications are real
  # layer-shell surfaces and there is a control centre (scrollback, DND,
  # volume/brightness sliders) rather than popups only.
  #
  # The Home Manager module already ships the systemd user unit (Type=dbus,
  # BusName=org.freedesktop.Notifications, WantedBy = wayland.systemd.target,
  # which this repo pins to sway-session.target in ../sway/default.nix), so
  # nothing execs it from the sway config and no autostart entry is needed.
  #
  # Style is the official Dracula port, kept as a file beside this module
  # (642 lines -- not inlined into Nix); see style.css for its one local edit.
  #
  # NOTE: home-manager's services.swaync does NOT pull in libnotify, but the
  # brightness/volume bindings in ../sway/config.nix call notify-send. Without
  # the explicit package below the daemon would run and those OSDs would
  # silently do nothing.
  services.swaync = {
    enable = true;
    package = pkgs.unstable.swaynotificationcenter;
    style = ./style.css;

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
      # That file is where this repo imports the Dracula GTK theme, and that
      # theme paints `.background { background-color: #1e1f29 }` -- on a *user*
      # provider, which beats swaync's application-level one. Result: the
      # notification layer surface (full monitor height, mostly empty) rendered
      # as a solid #1e1f29 slab down to the bottom of the screen. Measured the
      # slab pixels: exactly #1e1f29, i.e. the theme's colour.
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
    };
  };

  # notify-send, for the brightness/volume bindings in ../sway/config.nix.
  home.packages = [ pkgs.libnotify ];
}
