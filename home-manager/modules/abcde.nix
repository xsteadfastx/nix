{
  pkgs,
  ...
}:
let
  inherit (pkgs.unstable) abcde;
in
{
  home.packages = [
    abcde
  ];

  home.file.".abcde.conf".text = ''
    CDDBMETHOD=musicbrainz,cdtext
    CDROMREADERSYNTAX=cdparanoia
    CDPARANOIAOPTS="--never-skip=40 --sample-offset=+6"
    OUTPUTTYPE=flac
    OUTPUTDIR="$HOME/permanent/syncthing_mediashare/new"
    WAVOUTPUTDIR="/tmp/abcde-working"
  '';
}
