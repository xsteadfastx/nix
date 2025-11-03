{ ... }:
{
  nixpkgs.system = "aarch64-linux";
  nixpkgs.config.allowUnsupportedSystem = true;

  networking.hostName = "phil";

  security.sudo.wheelNeedsPassword = false;

  nix.settings.trusted-users = [
    "root"
    "marv"
  ];

  # users.users.root.initialPassword = "nixos";

  services.tailscale = {
    enable = true;
  };

  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";

  zramSwap.enable = true;
  zramSwap.memoryPercent = 150;

  boot.kernel.sysctl."vm.swappiness" = 100;

  system.stateVersion = "25.05";
}
