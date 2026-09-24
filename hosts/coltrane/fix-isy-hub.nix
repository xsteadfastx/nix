{ ... }:
{
  # Keep USB/Thunderbolt controllers and the ISY USB-C hub powered to prevent
  # dropouts. DP itself runs over the TB/DP-alt-mode path, not this hub.
  #
  # The boot-time MST rebind (isy-hub-mst-init) was removed: a live test showed
  # the hub rebind emits no DP/HPD events (DP runs over the TB/DP-alt-mode path,
  # not this USB hub), and its DP-1-3/DP-1-4 guard never matched because xe now
  # enumerates the MST sub-connectors as DP-6/DP-7. So it re-bound the hub and
  # then polled 30s on every boot *and* soft-reboot for nothing. Output
  # enumeration is sway's job now: wlroots force-scans all DRM connectors at
  # backend start, on session resume, and on hotplug, while kanshi and
  # sway-outputs match by EDID, independent of the connector names.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x64a0", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa831", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa833", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa834", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa87d", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="05e3", ATTRS{idProduct}=="0626", ATTR{power/control}="on"
  '';
}
