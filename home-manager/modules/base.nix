{
  pkgs,
  nixosConfig,
  lib,
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

  home.packages = with pkgs; [
    # systemtools
    unstable.appimage-run
    unstable.bandwhich # traffic
    unstable.bat
    unstable.eza
    unstable.fzf
    unstable.nodejs
    unstable.progress
    unstable.python3
    unstable.rlwrap
    unstable.unzip
    unstable.viddy
    unstable.vimv

    # go
    unstable.go

    # dev
    unstable.gcc

    # download stuff
    unstable.aria2
    unstable.yt-dlp

    (writeShellScriptBin "yt-dlp-album" ''
      set -euo pipefail
      if [ "$#" -ne 1 ]; then
      	echo "Error: One argument needed (URL)."
      	echo "Usage: yt-dlp-album <URL>"
      	exit 1
      fi
      ${unstable.yt-dlp}/bin/yt-dlp -x --audio-format mp3 --audio-quality 0 -i -o "%(album)s/%(title)s-%(id)s.%(ext)s" --cookies-from-browser chromium $1
    '')

    # backup
    unstable.restic

    # filetransfer
    localsend-go

    # passwords
    git-credential-gopass
    gopass

    # other tools
    bumblebee-status
    tectonic
    unstable.cook-cli
    unstable.babelfish
    unstable.compose2nix
    unstable.croc
    unstable.doggo
    unstable.fx
    unstable.githubCliTokenWrapped
    unstable.glab
    unstable.go-task
    unstable.pandoc
    unstable.qrcp # easy sending files to android
    unstable.rclone
    unstable.w3m
    unstable.yaegi

    # vpn
    (writeShellScriptBin "wobcom-vpn" ''
      set -e

      ${tmux}/bin/tmux rename-window "wobcom-vpn"
      sudo ${unstable.openfortivpn}/bin/openfortivpn \
      	vpn.wobcom.de \
      	--trusted-cert 7a3f29e18c303c26080671cd1c0925ba2ae7c229c50eef6222d6f1453596e88d \
      	--trusted-cert c815544ef4367147ab4bc564430efd72258eb2f6e1d634503c2f48c7b77da544 \
      	--trusted-cert  53867d23d82092af1800dd1b1555025a50a3d8ab97746247ed95d1080b20d71e \
      	-u mpreuss \
      	-p $(${gopass}/bin/gopass show -o websites/id.wobcom.de/marvin.preuss@wobcom.de)
    '')

    # ssh
    unstable.sshfs

    # camera
    unstable.airmtp
    unstable.imagingedge4linux
    unstable.importsony
    unstable.importsony-jpegs

    # music
    unstable.picard

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
