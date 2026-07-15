{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  nixpkgs.overlays = [
    # Single overlay that composes both the custom package overrides AND the
    # coding-agent's pinned unstable packages (pi, agent-browser, mcp-*,
    # claude-code). overlays/default.nix merges overlays/coding-agent.nix and
    # owns the one nixpkgs-unstable import (exposed as pkgs.unstable).
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
    vim
    wget
  ];
}
