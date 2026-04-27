{ ... }:
{
  # Don't create default ~/Sync folder
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "marv";
    dataDir = "/home/marv/permanent";
    configDir = "/home/marv/.config/syncthing";
  };
}
