{ lib, pkgs, ... }:
{
  nixpkgs = {
    buildPlatform = "x86_64-linux";
    hostPlatform = "aarch64-linux";
    overlays = [
      (_: prev: {
        # ncdu uses Zig which doesn't cross-compile properly in nixpkgs
        ncdu = prev.writeShellScriptBin "ncdu" ''
          echo "ncdu: not available (Zig cross-compilation limitation)" >&2
          exit 1
        '';
      })
    ];
  };

  # phil doesn't use ZFS; silence the 26.11 deprecation warning (also applies
  # to the phil-sdcard-img build, which bypasses the hive's base module).
  boot = {
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
