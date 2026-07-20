_:
let
  # forgejoUser = "forgejo";
  forgejoData = "/var/lib/forgejo";

  # migrate-forgejo = pkgs.writeShellScriptBin "migrate-forgejo" ''
  #   set -euo pipefail
  #
  #   # SOURCE PATHS - Adjust these to where your Gitea data currently sits
  #   SRC_REPOS="/tmp/shared/gitea/git/repositories"
  #   SRC_DATA="/tmp/shared/gitea/gitea"
  #
  #   DST="${forgejoData}"
  #   USER="${forgejoUser}"
  #
  #   echo "==> Stopping Forgejo service"
  #   systemctl stop forgejo || true
  #
  #   echo "==> Creating directory structure"
  #   mkdir -p "$DST/data" "$DST/repositories" "$DST/custom/conf"
  #
  #   echo "==> Copying Repositories (Git data)"
  #   if [ -d "$SRC_REPOS" ]; then
  #     rsync -avh "$SRC_REPOS/" "$DST/repositories/"
  #   else
  #     echo "ERROR: Source repositories not found at $SRC_REPOS"
  #     exit 1
  #   fi
  #
  #   echo "==> Copying Database and Data blobs"
  #   if [ -d "$SRC_DATA" ]; then
  #     # This copies the actual gitea.db file safely as a binary
  #     rsync -avh "$SRC_DATA/" "$DST/data/"
  #   else
  #     echo "ERROR: Source data not found at $SRC_DATA"
  #     exit 1
  #   fi
  #
  #   echo "==> Handling configuration (app.ini)"
  #   if [ -f "$DST/data/conf/app.ini" ]; then
  #     mv -f "$DST/data/conf/app.ini" "$DST/custom/conf/app.ini"
  #   fi
  #
  #   echo "==> Updating paths in app.ini (TEXT ONLY)"
  #   if [ -f "$DST/custom/conf/app.ini" ]; then
  #     # Replace old internal paths with the new NixOS standard path
  #     sed -i "s|/var/lib/gitea|$DST|g" "$DST/custom/conf/app.ini"
  #     sed -i "s|/data/gitea|$DST/data|g" "$DST/custom/conf/app.ini"
  #     sed -i "s|/data/git/repositories|$DST/repositories|g" "$DST/custom/conf/app.ini"
  #   fi
  #
  #   echo "==> Renaming db"
  #   mv -f "$DST/data/gitea.db" "$DST/data/forgejo.db"
  #
  #   echo "==> Fixing ownership for user: $USER"
  #   chown -R "$USER:$USER" "$DST"
  #
  #   echo "==> Starting Forgejo"
  #   systemctl start forgejo
  #
  #   echo "==> Migration complete. Checking status..."
  #   systemctl status forgejo --no-pager
  #'';
in
{
  networking.firewall.allowedTCPPorts = [ 3000 ];

  services.forgejo = {
    enable = true;
    stateDir = forgejoData;
    database.type = "sqlite3";

    settings = {
      DEFAULT = {
        RUN_MODE = "prod";
      };

      server = {
        DISABLE_SSH = true;
        DOMAIN = "git.xsfx.dev";
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = 3000;
        PROTOCOL = "http";
        ROOT_URL = "https://git.xsfx.dev";
      };

      service = {
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        DISABLE_REGISTRATION = true;
      };

      # Bots were walking every commit SHA of large mirrors (e.g.
      # prometheus/cadvisor) and hitting /<repo>/archive/<sha>.bundle, making
      # Forgejo generate + cache a full-repo bundle per request. That filled
      # the disk (~9.7G under data/repo-archive) and wedged the leveldb queue.
      # The `dlSourceEnabled` guard on the /archive/* route 404s before any
      # generation when this is set, killing the storm at the door.
      repository = {
        DISABLE_DOWNLOAD_SOURCE_ARCHIVES = true;
      };

      # Minimal-instance trimming: Forgejo enables these subsystems by default,
      # but this box runs none of them. Turning them off shrinks the attack /
      # disk-fill surface on a small VM. Matches the common self-hosted pattern.
      # - actions: no CI runners are registered, so it does nothing but expose
      #   the Actions API/UI.
      # - packages: the package registry stores arbitrary blobs on the same
      #   disk anonymously-reachably (another disk-fill vector like archives).
      actions.ENABLED = false;
      packages.ENABLED = false;

      # Not used here; disable to reduce surface further.
      # - federation: ActivityPub federation (experimental, unused).
      # - api: hide the /api/swagger interactive docs endpoint.
      federation.ENABLED = false;
      api.ENABLE_SWAGGER = false;

      session = {
        COOKIE_SECURE = true;
      };
    };
  };
}
