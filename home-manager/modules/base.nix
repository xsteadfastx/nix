{
  pkgs,
  nixosConfig,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
{
  imports = [
    ./abcde.nix
    ./aerc
    ./btop.nix
    ./cliamp.nix
    ./fish
    ./git.nix
    ./tmux
    ./whipper.nix
  ];

  systemd.user.startServices = "sd-switch";

  # Package channel convention:
  #   bare name    -> pkgs.unstable (nixpkgs-unstable + overlays.default)
  #   pkgs.<name>  -> stable nixpkgs (26.05) + overlays.default; use to PIN a
  #                   package to the stable channel (e.g. bumblebee-status,
  #                   gopass, tectonic)
  # Both channels carry overlays.default, so custom/overridden packages
  # (bumblebee-status w/ plugins, localsend-go, githubCliTokenWrapped, ...)
  # resolve either way — the prefix only chooses the channel.
  home.packages = with pkgs.unstable; [
    # systemtools
    appimage-run
    bandwhich # traffic
    bat
    eza
    fzf
    nodejs
    progress
    python3
    rlwrap
    unzip
    viddy
    vimv

    # go
    go

    # dev
    gcc

    # download stuff
    aria2
    yt-dlp
    (pkgs.writeShellScriptBin "yt-dlp-album" ''
      set -euo pipefail
      if [ "$#" -ne 1 ]; then
      	echo "Error: One argument needed (URL)."
      	echo "Usage: yt-dlp-album <URL>"
      	exit 1
      fi
      ${yt-dlp}/bin/yt-dlp -x --audio-format mp3 --audio-quality 0 -i -o "%(album)s/%(title)s-%(id)s.%(ext)s" --cookies-from-browser chromium $1
    '')

    # backup
    restic

    # filetransfer
    localsend-go

    # passwords
    pkgs.git-credential-gopass
    pkgs.gopass

    # other tools
    ansible
    babelfish
    pkgs.bumblebee-status
    compose2nix
    croc
    doggo
    fx
    glab
    githubCliTokenWrapped
    go-task
    pandoc
    pkgs.tectonic
    qrcp # easy sending files to android
    rclone
    w3m
    yaegi

    # vpn
    (writeShellScriptBin "wobcom-vpn" ''
      set -e

      ${tmux}/bin/tmux rename-window "wobcom-vpn"
      sudo ${openfortivpn}/bin/openfortivpn \
      	vpn.wobcom.de \
      	--trusted-cert 7a3f29e18c303c26080671cd1c0925ba2ae7c229c50eef6222d6f1453596e88d \
      	--trusted-cert c815544ef4367147ab4bc564430efd72258eb2f6e1d634503c2f48c7b77da544 \
      	--trusted-cert  53867d23d82092af1800dd1b1555025a50a3d8ab97746247ed95d1080b20d71e \
      	-u mpreuss \
      	-p $(${pkgs.gopass}/bin/gopass show -o websites/id.wobcom.de/marvin.preuss@wobcom.de)
    '')

    # ssh
    sshfs

    # camera
    airmtp
    imagingedge4linux
    importsony
    importsony-jpegs

    # music
    picard

    # work
    (lib.mkIf cfg.work kerouac)

    # caching
    attic
    (writeShellScriptBin "attic-push-store" ''
      set -euo pipefail
      ${attic}/bin/attic push --ignore-upstream-cache-filter iot $(ls -d /nix/store/*/ | grep armv5tel)
      ${attic}/bin/attic push --ignore-upstream-cache-filter iot $(ls -d /nix/store/*/ | grep chirpstack)
    '')
  ];

}
