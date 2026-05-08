{ pkgs, ... }:
{
  # Kernel params to stabilize USB and audio on Lunar Lake
  boot.kernelParams = [
    "snd_hda_intel.power_save=0"
    "snd_usb_audio.power_save=0"
    "usbcore.autosuspend=-1"
    "threadirqs"
    "pcie_aspm=off"
  ];

  # PipeWire realtime audio
  services.pipewire.extraConfig.pipewire."92-realtime" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 2048;
      "default.clock.min-quantum" = 1024;
      "default.clock.max-quantum" = 4096;
      "mem.allow-mlock" = true;
    };
    "context.modules" = [
      {
        name = "libpipewire-module-rtkit";
        args = {
          "nice.level" = -15;
          "rt.prio" = 88;
          "rt.time.soft" = 2000000;
          "rt.time.hard" = 2000000;
        };
      }
    ];
  };

  # Keep USB/Thunderbolt controllers and ISY hub powered to prevent dropouts
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa831", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa833", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa834", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa87d", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="05e3", ATTRS{idProduct}=="0626", ATTR{power/control}="on"
  '';

  # Lunar Lake RT714 mic uses DMIC3/DMIC4 inputs but the UCM BootSequence is
  # not executed by PipeWire, leaving the ADC mux at hardware defaults (MIC1/MIC2).
  # Re-apply after resume too since SoundWire codec registers reset on power cycle.
  systemd.services.rt714-mic-init = {
    description = "Initialize Lunar Lake RT714 microphone DMIC routing";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "rt714-mic-init" ''
        for i in $(seq 1 30); do
          ${pkgs.alsa-utils}/bin/amixer -c sofsoundwire info >/dev/null 2>&1 && break
          sleep 1
        done
        ${pkgs.alsa-utils}/bin/amixer -c sofsoundwire cset name='rt714 FU0A Capture Switch' off
        ${pkgs.alsa-utils}/bin/amixer -c sofsoundwire cset name='rt714 ADC 22 Mux' 'DMIC3'
        ${pkgs.alsa-utils}/bin/amixer -c sofsoundwire cset name='rt714 ADC 23 Mux' 'DMIC4'
        ${pkgs.alsa-utils}/bin/amixer -c sofsoundwire cset name='rt714 FU0C Boost' 2
        ${pkgs.alsa-utils}/bin/amixer -c sofsoundwire cset name='rt714 FU0E Boost' 2
        ${pkgs.alsa-utils}/bin/amixer -c sofsoundwire cset name='rt714 FU02 Capture Switch' on
        ${pkgs.alsa-utils}/bin/amixer -c sofsoundwire cset name='rt714 FU02 Capture Volume' 63
      '';
    };
  };

  systemd.services.isy-hub-mst-init = {
    description = "Rebind ISY USB-C hub to restore MST topology after boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "isy-hub-mst-init" ''
        for i in $(seq 1 20); do
          HUB=$(for d in /sys/bus/usb/devices/*/; do
            vid=$(cat "$d/idVendor" 2>/dev/null)
            pid=$(cat "$d/idProduct" 2>/dev/null)
            if [ "$vid" = "05e3" ] && [ "$pid" = "0626" ]; then
              basename "$d"
            fi
          done)
          [ -n "$HUB" ] && break
          sleep 1
        done
        if [ -n "$HUB" ]; then
          echo "$HUB" > /sys/bus/usb/drivers/usb/unbind
          sleep 2
          echo "$HUB" > /sys/bus/usb/drivers/usb/bind
        fi
      '';
    };
  };

  powerManagement.resumeCommands = ''
    systemctl restart rt714-mic-init.service
    # ISY USB-C hub (Genesys Logic 05e3:0626) collapses MST topology on suspend.
    # Unbind/rebind the USB device to trigger DP HPD and restore MST sub-ports.
    for d in /sys/bus/usb/devices/*/; do
      vid=$(cat "$d/idVendor" 2>/dev/null)
      pid=$(cat "$d/idProduct" 2>/dev/null)
      if [ "$vid" = "05e3" ] && [ "$pid" = "0626" ]; then
        hub=$(basename "$d")
        echo "$hub" > /sys/bus/usb/drivers/usb/unbind
        sleep 2
        echo "$hub" > /sys/bus/usb/drivers/usb/bind
      fi
    done
  '';
}
