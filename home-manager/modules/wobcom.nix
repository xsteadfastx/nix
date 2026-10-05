{
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  # The dial runs as root via sudo, so it takes the password on stdin instead of
  # as an argument: sudo writes its whole command line to the journal, which is
  # how the VPN password ended up there in plaintext on every connect. (The
  # openfortivpn process masks its own argv; sudo's copy is the leak.) Bonus:
  # what sudo execs is now an immutable store script, not a caller-supplied
  # string.
  dial = pkgs.writeShellScript "wobcom-vpn-dial" ''
    IFS= read -r pw
    exec ${pkgs.unstable.openfortivpn}/bin/openfortivpn \
      vpn.wobcom.de \
      --trusted-cert 7a3f29e18c303c26080671cd1c0925ba2ae7c229c50eef6222d6f1453596e88d \
      --trusted-cert c815544ef4367147ab4bc564430efd72258eb2f6e1d634503c2f48c7b77da544 \
      --trusted-cert 53867d23d82092af1800dd1b1555025a50a3d8ab97746247ed95d1080b20d71e \
      -u mpreuss \
      -p "$pw"
  '';
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

    # A tunnel that outlives the network (suspend, wifi switch, gateway drop)
    # wedges openfortivpn on a dead socket: it never notices, so its pppd and
    # ppp0 stay up and the next dial would hang until the stale instance is
    # killed by hand. Clear it first, then wait for it to release ppp0 before
    # dialing. `hosts/coltrane/configuration.nix` also tears the tunnel down
    # before sleeping, so the wedge is not created in the first place.
    (pkgs.writeShellScriptBin "wobcom-vpn" ''
      set -e
      if [ -n "''${ZELLIJ:-}" ]; then
        zellij action rename-tab wobcom-vpn
      elif [ -n "''${TMUX:-}" ]; then
        tmux rename-window wobcom-vpn
      fi
      sudo ${pkgs.procps}/bin/pkill -x openfortivpn || true
      for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
        ${pkgs.procps}/bin/pgrep -x openfortivpn > /dev/null || break
        sleep 0.2
      done
      ${pkgs.gopass}/bin/gopass show -o websites/id.wobcom.de/marvin.preuss@wobcom.de \
        | sudo ${dial}
    '')
  ];
}
