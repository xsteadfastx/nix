{
  pkgs,
  ...
}:
{
  imports = [
    ./abcde.nix
    ./aerc
    ./btop.nix
    ./cliamp.nix
    ./fish
    ./git.nix
    ./whipper.nix
    ./zellij
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
    unstable.p7zip
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
      ${unstable.yt-dlp}/bin/yt-dlp \
        -f 'ba*[ext=m4a]/ba*' \
        -x --audio-format m4a \
        --embed-metadata --embed-thumbnail --convert-thumbnails jpg \
        --parse-metadata "playlist_index:%(track_number)s" \
        --parse-metadata "%(album_artist,channel,creator,artist|Unknown)s:%(album_artist)s" \
        -o "%(album,playlist_title|Unknown)s/%(track_number,playlist_index)02d - %(title)s.%(ext)s" \
        --no-overwrites --concurrent-fragments 4 \
        --cookies-from-browser firefox \
        "$1"
    '')

    # backup
    unstable.restic

    # filetransfer
    localsend-go

    # passwords
    git-credential-gopass
    gopass

    # other tools
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

    # ssh
    unstable.sshfs

    # camera
    unstable.airmtp
    unstable.imagingedge4linux
    unstable.importsony
    unstable.importsony-jpegs

    # music
    unstable.picard

    # caching
    attic
    (writeShellScriptBin "attic-push-store" ''
      set -euo pipefail
      ${attic}/bin/attic push --ignore-upstream-cache-filter iot $(ls -d /nix/store/*/ | grep armv5tel)
      ${attic}/bin/attic push --ignore-upstream-cache-filter iot $(ls -d /nix/store/*/ | grep chirpstack)
    '')
  ];

}
