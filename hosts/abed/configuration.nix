_: {
  networking.hostName = "abed";
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
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "vm.swappiness" = 100;
  };
  nix.settings = {
    min-free = 2 * 1024 * 1024 * 1024;
    max-free = 5 * 1024 * 1024 * 1024;
  };
  nix.gc.options = "--delete-older-than 3d";
}
