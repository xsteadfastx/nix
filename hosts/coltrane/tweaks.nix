_: {
  # Kernel params to stabilize USB and audio on Lunar Lake
  boot.kernelParams = [
    "snd_hda_intel.power_save=0"
    "snd_usb_audio.power_save=0"
    "usbcore.autosuspend=-1"
    "threadirqs"
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

  # Keep USB/Thunderbolt controllers powered to prevent dropouts
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa833", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa834", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa87d", ATTR{power/control}="on"
  '';
}
