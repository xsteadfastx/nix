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
    # Slack runs unwrapped: it only renders a 10x10 stub window under the
    # bubblewrap sandbox on this X11/i3 box (sandbox display+GL+shm all
    # verified), so sandboxing it was reverted to keep a working app. If that
    # ever gets fixed, swap back to pkgs.slack-wrapped.
    pkgs.unstable.slack
    # 1Password, only the GUI is used; the GUI is sandboxed (bubblewrap) so a
    # compromise can't read the rest of $HOME.
    pkgs.onepassword-gui-wrapped
    pkgs.unstable._1password-cli
  ];
}
