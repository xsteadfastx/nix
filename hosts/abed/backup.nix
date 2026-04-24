{ config, ... }:
{
  services.restic.backups.remote-backup = {
    repositoryFile = config.sops.secrets."restic_repo_file".path;
    passwordFile = config.sops.secrets."restic_pass_file".path;
    paths = [
      "/var/lib/forgejo"
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
