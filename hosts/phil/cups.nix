{ pkgs, lib, ... }:
{
  systemd.services.cups.serviceConfig.ExecStartPre = lib.mkBefore [
    "${pkgs.coreutils}/bin/rm -f /var/lib/cups/cupsd.conf"
  ];
  services.printing = {
    enable = true;
    listenAddresses = [ "*:631" ];
    allowFrom = [ "all" ];
    browsing = true;
    drivers = with pkgs; [
      brlaser
    ];
    extraConf = ''
      DefaultShared Yes

      <Location />
        Order allow,deny
        Allow all
      </Location>
      <Location /admin>
        Order allow,deny
        Allow all
      </Location>
    '';
  };
  networking.firewall.allowedTCPPorts = [ 631 ];
  networking.firewall.allowedUDPPorts = [
    631
    5353
  ];
  hardware.printers = {
    ensurePrinters = [
      {
        name = "Brother-HL-L2340D";
        location = "Phil";
        deviceUri = "usb://Brother/HL-L2340D%20series?serial=E73870M5N464062";
        model = "drv:///brlaser.drv/brl2340d.ppd";
        ppdOptions.PageSize = "A4";
      }
    ];
    ensureDefaultPrinter = "Brother-HL-L2340D";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
      userServices = true;
    };
  };
}
