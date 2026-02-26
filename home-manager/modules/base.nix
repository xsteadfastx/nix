{
  pkgs,
  pkgsUnstable,
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
    ./fish
    ./git.nix
    ./tmux
    ./whipper.nix
  ];

  systemd.user.startServices = "sd-switch";

  home.packages = with pkgsUnstable; [
    # systemtools
    appimage-run
    bandwhich # traffic
    bat
    btop
    eza
    fd
    file
    fzf
    gping
    htop
    mtr
    ncdu
    nmap
    nodejs
    progress
    python3
    ripgrep
    rlwrap
    tree
    unzip
    viddy
    vimv

    # go
    go

    # dev
    gcc

    # k8s
    k9s
    krew
    kubectl
    kubectx

    # download stuff
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

    # other tools
    ansible
    babelfish
    bumblebee-status
    compose2nix
    croc
    doggo
    fx
    git-credential-gopass
    glab
    go-task
    gopass
    pandoc
    pkgs.gnupg
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
      -u mpreuss \
      -p $(${gopass}/bin/gopass show -o websites/id.wobcom.de/marvin.preuss@wobcom.de)
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
      ${attic}/bin/attic push --ignore-upstream-cache-filter iot $(ls -d /nix/store/*/|grep armv5tel)
      ${attic}/bin/attic push --ignore-upstream-cache-filter iot $(ls -d /nix/store/*/|grep chirpstack)
    '')
  ];

}
