{
  inputs,
  ...
}:
# bubblewrap (nixpak) sandboxed work apps. Runs AFTER the `unstable` overlay,
# so it can wrap unstable packages.
final: _prev:
let
  mkNixPak = inputs.nixpak.lib.nixpak {
    lib = final.unstable.lib;
    pkgs = final.unstable;
  };
in
{
  # The work machine's 1Password (GUI only), sandboxed so a compromise can't
  # read the rest of $HOME. No browser/CLI bridge, so no cross-sandbox sockets
  # to break. Bound to the host X11 socket (works on this box's X11/i3
  # session), with network + vault sync kept shared, fonts mounted, and only
  # its own config/cache writable. Wired into home.packages under
  # features.wobcom (see home-manager/modules/wobcom.nix).
  onepassword-gui-wrapped =
    (mkNixPak {
      config =
        { sloth, ... }:
        {
          app.package = final.unstable._1password-gui;
          flatpak.appId = "com.onepassword.OnePassword";
          fonts.enable = true;
          dbus.policies = {
            "org.freedesktop.secrets" = "talk";
            "org.freedesktop.Notifications" = "talk";
            "org.freedesktop.portal.*" = "talk";
          };
          bubblewrap = {
            network = true; # vault/account sync
            # display via the host X11 socket; mic/audio via these socket binds.
            sockets = {
              x11 = true;
              pipewire = true;
              pulse = true;
            };
            # Only 1Password's own config/cache is writable; the rest of $HOME
            # is out of reach.
            bind.rw = [
              (sloth.concat' sloth.homeDir "/.config/1Password")
              (sloth.concat' sloth.homeDir "/.cache/1Password")
            ];
            bind.ro = [
              "/etc/machine-id"
              "/run/dbus/system_bus_socket"
            ];
          };
        };
    }).config.env;
}
