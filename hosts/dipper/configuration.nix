_: {
  services.tailscale.enable = true;
  system.stateVersion = "25.05";
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 10;
  };
  boot.kernel.sysctl."vm.swappiness" = 100;
  networking.hostName = "dipper";
  security.sudo.wheelNeedsPassword = false;
  boot.loader.grub.enable = true;
  nix.settings = {
    min-free = 2 * 1024 * 1024 * 1024;
    max-free = 5 * 1024 * 1024 * 1024;
  };
  nix.gc.options = "--delete-older-than 3d";
}
