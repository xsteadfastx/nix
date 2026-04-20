{
  pkgs,
  ...
}:
let
  migrate-gitea = pkgs.writeShellScriptBin "migrate-gitea" ''
    set -euo pipefail

    SRC="/tmp/shared/gitea"
    DST="/var/lib/gitea"
    USER="gitea"
    GROUP="gitea"

    echo "==> stopping gitea"
    systemctl stop gitea || true

    echo "==> creating directories"
    mkdir -p "$DST/data" "$DST/repositories" "$DST/custom/conf" "$DST/.ssh"

    echo "==> copying repositories"
    rsync -a "$SRC/git/repositories/" "$DST/repositories/"

    echo "==> copying gitea data"
    rsync -a "$SRC/gitea/" "$DST/data/"

    echo "==> moving app.ini"
    if [ -f "$DST/data/conf/app.ini" ]; then
      mv -f "$DST/data/conf/app.ini" "$DST/custom/conf/app.ini"
    fi

    if [ -f "$SRC/gitea/conf/app.ini" ]; then
      cp -f "$SRC/gitea/conf/app.ini" "$DST/custom/conf/app.ini"
    fi

    echo "==> copying ssh keys (optional)"
    if [ -d "$SRC/ssh" ]; then
      rsync -a "$SRC/ssh/" "$DST/.ssh/"
      chmod 700 "$DST/.ssh"
    fi

    echo "==> fixing ownership"
    chown -R "$USER:$GROUP" "$DST"

    echo "==> fixing app.ini paths"
    if [ -f "$DST/custom/conf/app.ini" ]; then
      sed -i 's|/data/gitea/gitea.db|/var/lib/gitea/data/gitea.db|g' "$DST/custom/conf/app.ini"
      sed -i 's|/data/git/repositories|/var/lib/gitea/repositories|g' "$DST/custom/conf/app.ini"
    fi

    echo "==> starting gitea"
    systemctl start gitea

    echo "==> done"
    journalctl -u gitea -n 30 --no-pager
  '';
in
{
  networking.firewall.allowedTCPPorts = [ 3000 ];

  environment.systemPackages = [
    migrate-gitea
  ];

  services.gitea = {
    enable = true;
    stateDir = "/var/lib/gitea";
    settings = {
      server = {
        ROOT_URL = "https://git.xsfx.dev/";
      };
    };
  };
}
