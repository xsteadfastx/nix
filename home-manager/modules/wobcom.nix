{
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;
in
{
  # Wobcom work apps, gated by features.wobcom (set on the work machine,
  # coltrane).
  home.packages = lib.mkIf cfg.wobcom [
    # Slack and the 1Password GUI, both sandboxed with nixpak (bubblewrap):
    # a compromise can't read the rest of $HOME, and Wayland goes through
    # nixpak's wayland-proxy so the app can't screencopy/snoop other windows.
    pkgs.slack-wrapped
    pkgs.onepassword-gui-wrapped
    pkgs.unstable._1password-cli
  ];
}
