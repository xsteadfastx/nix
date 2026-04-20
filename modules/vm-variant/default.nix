{ lib, ... }:
{
  virtualisation.vmVariant = {
    virtualisation = {
      diskSize = 10 * 1024;
      memorySize = 4 * 1024;
      cores = 2;
      sharedDirectories = {
        keys = {
          source = "/etc/ssh";
          target = "/etc/ssh";
        };
      };
    };
    boot.growPartition = lib.mkForce false;
    networking.useDHCP = lib.mkForce true;
    networking.useNetworkd = lib.mkForce false;
    services.cloud-init.enable = false;
    systemd.network.enable = lib.mkForce false;
    users.users.root.initialPassword = "notsafe";
  };
}
