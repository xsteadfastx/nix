{ lib, pkgs, ... }:
{
  networking.hostName = "phil";
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_rpi3;
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
  environment.systemPackages = [ pkgs.usbutils ];
}
