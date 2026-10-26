{ lib, pkgs, ... }:
{
  # Native aarch64 (hardware-configuration sets hostPlatform): colmena builds
  # on the Pi itself, see hive.nix. Native is what cache.nixos.org carries —
  # no cross, so nothing has to be compiled from source.

  # A Pi has no GRUB; the firmware/U-Boot chain reads extlinux.conf. All that
  # nixos-hardware's raspberry-pi module still contributed: its other payload is
  # a hand-built rpi kernel, and no cache carries those (see hive.nix).
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    # phil doesn't use ZFS; silence the 26.11 deprecation warning (also applies
    # to the phil-sdcard-img build, which bypasses the hive's base module).
    zfs.forceImportRoot = false;
    tmp = {
      useTmpfs = true;
      tmpfsSize = "50%";
    };
    kernel.sysctl = {
      "vm.swappiness" = 100;
      "vm.mmap_rnd_bits" = lib.mkForce 24;
    };
  };

  networking.hostName = "phil";
  security.sudo.wheelNeedsPassword = false;
  nix = {
    settings = {
      trusted-users = [
        "root"
        "marv"
      ];
      min-free = 2 * 1024 * 1024 * 1024;
      max-free = 5 * 1024 * 1024 * 1024;
    };
    gc.options = "--delete-older-than 3d";
  };
  services.tailscale = {
    enable = true;
  };
  zramSwap.enable = true;
  zramSwap.memoryPercent = 150;
  system.stateVersion = "25.05";

  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=64M
  '';

  fileSystems."/var/log" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=32M"
      "mode=0755"
      "noatime"
    ];
  };

  virtualisation.vmVariant = {
    boot.kernelPackages = lib.mkOverride 10 pkgs.linuxPackages;
  };

  environment.systemPackages = [ pkgs.usbutils ];
}
