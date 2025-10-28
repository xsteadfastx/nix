{
  airmtp,
  rclone,
  writeShellScriptBin,
  systemdMinimal,
  ...
}:
writeShellScriptBin "importsony" ''
  set -eo pipefail

  FORMAT="+%m/%d/%y"
  NOW=$(date $FORMAT)
  STARTDATE="$1"

  TMPDIR=$(mktemp -p ~/tmp -d -t photoprism-XXXXXXX)

  SYSTEMCTL="sudo ${systemdMinimal}/bin/systemctl"

  function cleanup() {
    echo "Cleanup..."

    echo "Removing $TMPDIR"
    rm -rf $TMPDIR

    echo "Starting firewall..."
    $SYSTEMCTL start firewall.service

    echo "Done."
  }

  function download() {
    echo "Downloading photos from $FROM on..."

    ${airmtp}/bin/airmtp --ipaddress auto --outputdir "$TMPDIR" --startdate "$FROM"
  }

  function copy() {
    echo "Copy..."

    ${rclone}/bin/rclone copy -P "$TMPDIR" photoprism-import:
  }

  function main() {
    if [ -z "$STARTDATE" ]
    then
      echo "No startdate, will use $NOW"
      FROM=$NOW
    else
      FROM=$(date --date="$STARTDATE" $FORMAT)
    fi

    echo "Temp stopping firewall..."
    $SYSTEMCTL stop firewall.service

    download
    copy

    exit 0
  }

  trap cleanup EXIT
  trap cleanup SIGINT

  main
''
