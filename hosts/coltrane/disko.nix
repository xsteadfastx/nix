{ pkgs, ... }:
{
  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs = {
      forceImportRoot = true;
      requestEncryptionCredentials = true;
    };
    # zram (below) is the only swap, and swapping a page into it costs a
    # memcpy + zstd instead of a disk seek -- the assumption behind the default
    # 60. Values above 100 are what the kernel doc recommends for in-memory
    # swap, and what zram tuning upstream uses (Arch/Pop!_OS 180, e.g.
    # OmerFarukOruc/nixos-config 150): prefer compressing a cold anon page
    # (~3:1 here, 8.9 GB held in 2.8 GB of RAM) over dropping page cache that
    # then has to be read back from ZFS. Not 180: the ZFS ARC (capped 8 GiB,
    # invisible to MemAvailable) makes this box less cache-expendable than the
    # desktops those tunings come from. Only has an effect under memory
    # pressure -- if pswpout barely grows, it is doing nothing.
    kernel.sysctl."vm.swappiness" = 150;
  };
  environment.systemPackages = [ pkgs.zfs ];
  networking.hostId = "00000001";

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };
    zpool = {
      zroot = {
        type = "zpool";
        rootFsOptions = {
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
          "com.sun:auto-snapshot" = "false";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };
        };
      };
    };
  };
}
