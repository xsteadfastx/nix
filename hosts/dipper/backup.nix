{ config, ... }:
{
  # Restic backups, mirroring hosts/abed/backup.nix. Backs up the persistent
  # Matrix state: homeserver DB + media (tuwunel) and the WhatsApp/Signal/
  # Telegram bridge session DBs (losing these = having to re-pair the bridges).
  services.restic.backups.remote-backup = {
    repositoryFile = config.sops.secrets."restic_repo_file".path;
    passwordFile = config.sops.secrets."restic_pass_file".path;
    paths = [
      "/var/lib/tuwunel" # homeserver RocksDB + media
      "/var/lib/mautrix-telegram"
      "/var/lib/mautrix-whatsapp"
      "/var/lib/mautrix-signal"
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
