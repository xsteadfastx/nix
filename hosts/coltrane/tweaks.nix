{ ... }:
{
  # Kernel params to stabilize USB and audio on Lunar Lake
  boot.kernelParams = [
    "snd_hda_intel.power_save=0"
    "snd_usb_audio.power_save=0"
    "usbcore.autosuspend=-1"
    "threadirqs"
    "pcie_aspm=off"
  ];
}
