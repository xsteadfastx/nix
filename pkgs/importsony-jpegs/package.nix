{
  imagingedge4linux,
  networkmanager,
  rclone,
  writeShellScriptBin,
  ...
}:
writeShellScriptBin "importsony-jpegs" ''
  set -euo pipefail

  SSID="DIRECT-wRE0:Stevie's_Alpha7II"
  PASSWORD="FdsmQEwS"
  DEV="wlp2s0"

  TMPDIR=$(mktemp -p ~/tmp -d -t photoprism-XXXXXXX)

  NMCLI=${networkmanager}/bin/nmcli

  CURRENT_SSID=$($NMCLI -t c show --active | grep "$DEV" | head -n 1 | cut -d ':' -f 1)

  $NMCLI connection delete "$SSID" || true
  sleep 2
  $NMCLI dev wifi connect "$SSID" password "$PASSWORD"

  echo "Waiting..."
  sleep 6

  ${imagingedge4linux}/bin/imagingedge4linux -o $TMPDIR

  if [ -n "$CURRENT_SSID" ]; then
    echo "Reconnecting to the previously connected network..."
    $NMCLI con up "$CURRENT_SSID"
  else
    echo "No previously connected network found."
    exit 1
  fi

  echo "Copy to photoprism..."
  # ${rclone}/bin/rclone copy -P "$TMPDIR/PushRoot" photoprism-import:

  echo "Removing tmp dir $TMPDIR..."
  # rm -rf $TMPDIR

  echo "Done."
''
