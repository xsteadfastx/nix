{ pkgs, ... }:
{
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

  powerManagement.resumeCommands = ''
    systemctl restart rt714-mic-init.service
  '';
}
