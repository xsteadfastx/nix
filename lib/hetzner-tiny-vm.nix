# The small Hetzner cloud VMs (abed, dipper): same disk layout, same uplink
# shape, same baseline settings. Only the IPv6 address differs, so this is a
# function -- like lib.mkNodeExporter beside it -- called in hive.nix where each
# host's addresses live.
ipv6Address: {
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02";
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    networks."10-uplink" = {
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      address = [ ipv6Address ];
      routes = [
        {
          Gateway = "172.31.1.1";
          GatewayOnLink = true;
        }
        {
          Gateway = "fe80::1";
        }
      ];
    };
  };

  services.tailscale.enable = true;

  system.stateVersion = "25.05";

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 10;
  };

  security.sudo.wheelNeedsPassword = false;

  boot.loader.grub.enable = true;
  boot.kernel.sysctl."vm.swappiness" = 100;

  nix.settings = {
    min-free = 2 * 1024 * 1024 * 1024;
    max-free = 5 * 1024 * 1024 * 1024;
  };
  nix.gc.options = "--delete-older-than 3d";
}
