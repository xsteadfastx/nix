{ pkgs, ... }:
{
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
      {
        name = "Brother-HL-L2340D-VILLA-ANNA";
        deviceUri = "ipp://100.64.218.104:631/printers/Brother-HL-L2340D";
        model = "everywhere";
        ppdOptions.PageSize = "A4";
      }
    ];
    ensureDefaultPrinter = "Brother-HL-1110-USB";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
  };
}
