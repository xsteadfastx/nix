{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  nixpkgs.overlays = [
    # The single overlay: custom package overrides + the coding-agent repo's
    # packages (pi, mcp-*, claude-code), exposed as plain pkgs.* attrs that the
    # coding-agent module reads directly. overlays/default.nix applies the repo
    # overlay to this repo's nixos-unstable instance (where the Python MCP
    # servers' deps exist) and surfaces the names at the top level.
    inputs.self.overlays.default
  ];

  nix.settings = {
    trusted-users = [
      "root"
    ];

    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    experimental-features = [
      "nix-command"
      "flakes"
    ];

    auto-optimise-store = true;
    min-free = lib.mkDefault (5 * 1024 * 1024 * 1024);
    max-free = lib.mkDefault (15 * 1024 * 1024 * 1024);
  };

  nix.gc = {
    automatic = true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;

  services.xserver.xkb.options = "caps:escape";
  console.useXkbConfig = true;

  boot.loader.systemd-boot.configurationLimit = 10;

  services.resolved = {
    enable = lib.mkDefault true;
    settings.Resolve.FallbackDNS = lib.mkDefault [
      "1.1.1.1"
      "9.9.9.9"
      "8.8.8.8"
      "8.8.4.4"
    ];
  };

  environment.systemPackages = with pkgs; [
    btop
    fd
    file
    gping
    htop
    mtr
    ncdu
    net-tools
    nmap
    ripgrep
    tmux
    tree
    trippy-dracula
    vim
    wget
  ];
}
