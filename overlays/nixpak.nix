{ inputs, ... }:
# bubblewrap (nixpak) sandboxed work apps. Runs AFTER the `unstable` overlay,
# so it can wrap unstable packages.
#
# Wayland is routed through nixpak's `waylandProxy` (wayland-proxy-virtwl):
# the launcher runs the proxy *outside* the sandbox, binds only the proxy
# socket in, and sets WAYLAND_DISPLAY=nixpak-wayland. The app therefore never
# gets the raw compositor socket, so it cannot bind wlr-screencopy /
# wlr-foreign-toplevel / wlr-data-control -- which a raw-socket sandbox (e.g.
# nixwrap) cannot prevent.
final: _prev:
let
  mkNixPak = inputs.nixpak.lib.nixpak {
    lib = final.unstable.lib;
    pkgs = final.unstable;
  };

  common =
    { ... }:
    {
      fonts.enable = true;
      gpu.enable = true;
      waylandProxy.enable = true;
      bubblewrap = {
        network = true; # sync / calls
        # audio in + out (huddles / unlock sounds); display comes via waylandProxy
        sockets = {
          pipewire = true;
          pulse = true;
        };
        bind.ro = [ "/etc/machine-id" ];
      };
    };
in
{
  # GUI-only 1Password. No browser/CLI bridge, so no cross-sandbox sockets to
  # break. Only its own config/cache is writable; the rest of $HOME is out.
  onepassword-gui-wrapped =
    (mkNixPak {
      config =
        { sloth, ... }:
        {
          imports = [ common ];
          app.package = final.unstable._1password-gui;
          flatpak.appId = "com.onepassword.OnePassword";
          dbus.policies = {
            "org.freedesktop.secrets" = "talk";
            "org.freedesktop.Notifications" = "talk";
            "org.freedesktop.portal.*" = "talk";
          };
          bubblewrap.bind.rw = [
            (sloth.concat' sloth.homeDir "/.config/1Password")
            (sloth.concat' sloth.homeDir "/.cache/1Password")
          ];
          bubblewrap.bind.ro = [ "/run/dbus/system_bus_socket" ];
        };
    }).config.env;

  # Slack: network + audio (huddles) + DBus; only its own config/cache writable.
  slack-wrapped =
    (mkNixPak {
      config =
        { sloth, ... }:
        {
          imports = [ common ];
          app.package = final.unstable.slack;
          flatpak.appId = "com.slack.Slack";
          dbus.policies = {
            "org.freedesktop.portal.*" = "talk";
            "org.freedesktop.Notifications" = "talk";
            "org.kde.StatusNotifierWatcher" = "talk";
            "com.canonical.AppMenu.Registrar" = "talk";
          };
          bubblewrap.bind.rw = [
            (sloth.concat' sloth.homeDir "/.config/Slack")
            (sloth.concat' sloth.homeDir "/.cache/Slack")
          ];
          bubblewrap.bind.ro = [
            # Chromium reads /etc/lsb-release then /etc/os-release *very* early
            # (base::SysInfo::GetLinuxDistro); without one of them the renderer
            # never spawns and the main window never appears.
            "/etc/os-release"
          ];
        };
    }).config.env;
}
