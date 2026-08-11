{ pkgs, ... }:
{
  # ponytail: ensure-printers.service was deleted — it hit Tailscale at boot
  # (100.64.218.104 unreachable → exit code 1 → restart every 30s → forever).
  # Local USB printer stays in hardware.printers. Remote IPP gets updated via a
  # timer that runs once after boot + every 6h; lpadmin is idempotent so it's
  # safe to fire without checking connectivity first.

  services.printing = {
    enable = true;
    drivers = [
      pkgs.brlaser
      pkgs.brgenml1lpr
      pkgs.brgenml1cupswrapper
    ];
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Brother-HL-1110-USB";
        deviceUri = "usb://Brother/HL-1110%20series?serial=K3N519570";
        model = "drv:///brlaser.drv/br1110.ppd";
        ppdOptions.PageSize = "A4";
      }
    ];
    ensureDefaultPrinter = "Brother-HL-1110-USB";
  };

  # Timer-driven remote IPP printer registration — runs once at boot (5min after
  # startup, giving Tailscale time to connect) then every 6h. lpadmin is
  # idempotent; harmless to call when the target is down.
  systemd.timers.cups-update-remote-printer = {
    description = "Update remote IPP printer config via lpadmin";
    timerConfig.OnBootSec = "5min";
    timerConfig.OnUnitActiveSec = "6h";
    timerConfig.RandomizedDelaySec = "1min";
    wantedBy = [ "timers.target" ];
  };

  systemd.services.cups-update-remote-printer = {
    description = "Ensure remote Brother HL-L2340D lpadmin entry exists";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.cups}/bin/lpadmin -m everywhere -o PageSize=A4 \
        -p Brother-HL-L2340D-VILLA-ANNA \
        -v 'ipp://100.64.218.104:631/printers/Brother-HL-L2340D' -E || true
    '';
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
  };
}
