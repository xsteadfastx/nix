{ ... }:
{
  # Kernel params to stabilize USB and audio on Lunar Lake
  boot.kernelParams = [
    "snd_hda_intel.power_save=0"
    "snd_usb_audio.power_save=0"
    "usbcore.autosuspend=-1"
    "threadirqs"
    "pcie_aspm=off"
    "xe.enable_psr=0"
    # DP-MST over the USB-C/DP-altmode dock dies after s2idle resume: the DP
    # altmode stays active at the PD level (svid ff01) but xe no longer links
    # the DRM connector -> all DP outputs disconnected, no HPD. No runtime lever
    # recovers it (hub rebind, cable replug, echo detect, altmode toggle blocked
    # by firmware). DC5/DC6 display power gating during sleep is the likely
    # cause -> disable it.
    "xe.enable_dc=0"
  ];
}
