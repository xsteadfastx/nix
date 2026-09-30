{ config, ... }:
{
  # Restic backups, mirroring hosts/abed/backup.nix. Backs up the persistent
  # Matrix state: homeserver DB + media (tuwunel) and every bridge session DB
  # (losing those = having to re-pair the bridges).
  services.restic.backups.remote-backup = {
    repositoryFile = config.sops.secrets."restic_repo_file".path;
    passwordFile = config.sops.secrets."restic_pass_file".path;
    paths = [
      "/var/lib/tuwunel" # homeserver RocksDB + media
      # Every bridge's session DB. The module hands `paths` to restic's
      # --files-from, which expands globs, so a new bridge needs no change here.
      "/var/lib/mautrix-*"
    ];
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 12"
    ];
    timerConfig = {
      OnCalendar = "daily";
    };
    createWrapper = true;
  };
}
