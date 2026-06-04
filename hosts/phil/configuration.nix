{ lib, pkgs, ... }:
{
  nixpkgs.buildPlatform = "x86_64-linux";
  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.overlays = [
    (_: prev: {
      # ncdu uses Zig which doesn't cross-compile properly in nixpkgs
      ncdu = prev.writeShellScriptBin "ncdu" ''
        echo "ncdu: not available (Zig cross-compilation limitation)" >&2
        exit 1
      '';
    })
  ];

  networking.hostName = "phil";
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [
    "root"
    "marv"
  ];
  services.tailscale = {
    enable = true;
  };
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";
  zramSwap.enable = true;
  zramSwap.memoryPercent = 150;
  boot.kernel.sysctl."vm.swappiness" = 100;
  boot.kernel.sysctl."vm.mmap_rnd_bits" = lib.mkForce 24;
  system.stateVersion = "25.05";
  nix.settings = {
    min-free = 2 * 1024 * 1024 * 1024;
    max-free = 5 * 1024 * 1024 * 1024;
  };
  nix.gc.options = "--delete-older-than 3d";

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
