{ pkgs, ... }:
let
  # 1200-baud "touch" that makes an nRF52 app firmware reboot into its DFU
  # bootloader (see the ThinkNode rule below for why Chromium can't do this).
  # Guarded by a /run stamp: the bootloader hands back to the app after ~2 min,
  # which re-adds this tty, so an unguarded rule would touch again forever.
  meshcoreDfuTouch = pkgs.writeShellApplication {
    name = "meshcore-dfu-touch";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      stamp=/run/meshcore-dfu-touch.stamp
      if [[ -e $stamp && $(( $(date +%s) - $(stat -c %Y "$stamp") )) -lt 300 ]]; then
        exit 0
      fi
      stty -F "$1" 1200
      touch "$stamp"
    '';
  };
in
{
  # Web Serial workarounds for our LoRa devices. All of them are consequences of
  # a single Chromium bug: on glibc >= 2.42 the B<rate> macros are plain
  # integers (B115200 == 115200), but Chromium still writes them raw into
  # c_cflag (`c_cflag &= ~CBAUD; c_cflag |= B<rate>`) instead of using BOTHER +
  # c_ospeed. The result always lands as CBAUD = 0 (B0), so Chromium silently
  # fails to set *any* baud rate. Real fix: patch Chromium (full rebuild);
  # everything below works around it at plug-in time instead.
  #
  # Heltec V3 / CP210x USB-UART bridge (10c4:ea60): pre-set the tty on plug-in.
  #
  # 1. Baud rate: B115200 is now the plain number 115200, so Chromium leaves
  #    CBAUD=B0 and the chip keeps its previous speed (9600 on a fresh plug);
  #    the app then times out with "Failed to fetch device info". Pre-set
  #    115200 so that ignored speed change doesn't matter.
  #    ponytail: only covers 115200; a flasher switching baud mid-flash still
  #    breaks. Real fix: patch Chromium to use BOTHER + c_ospeed.
  # 2. VMIN=0 (left by pyserial: esptool, meshcore-cli, ...; the kernel keeps
  #    termios per tty index across unplug until reboot): Chromium inherits it,
  #    a non-blocking read() returns 0, and Chromium reports "The device has
  #    been lost". Restore min 1 time 0. Re-plug after using a pyserial tool.
  #
  # ModemManager's 80-mm-candidate.rules also AT-probes every USB-serial tty
  # as a possible modem and races the reset -- ignore this device.
  #
  # Elecrow ThinkNode M1 (nRF52, 239a:4405): flasher.meshcore.io can only write
  # it when it is already in its DFU bootloader. Getting it there needs a
  # 1200-baud touch, which is exactly the case the rule above cannot cover:
  # Chromium does `c_cflag &= ~CBAUD; c_cflag |= B1200` and on glibc >= 2.42
  # B1200 is the plain number 1200, so CBAUD ends up B0 and the device never
  # sees 1200. Doing the touch here from stty (which uses cfsetispeed and does
  # set 1200 correctly) opens the flasher's DFU window on plug-in.
  #
  # ponytail: the bootloader self-exits after ~2 min, re-adding this tty, so the
  # script stamps /run and refuses to touch again for 5 min -- without that the
  # M1 would bounce app <-> bootloader forever and never run its firmware.
  # Cost: the M1 sits in its bootloader for ~2 min after every plug-in here.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ENV{ID_MM_DEVICE_IGNORE}="1", RUN+="${pkgs.coreutils}/bin/stty -F $devnode 115200 min 1 time 0"
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="239a", ATTRS{idProduct}=="4405", RUN+="${meshcoreDfuTouch}/bin/meshcore-dfu-touch $devnode"
  '';
}
