{ ... }:
{
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.kernelParams = [
    "console=ttyS1,115200n8"
  ];

  system.stateVersion = "25.05";
}
