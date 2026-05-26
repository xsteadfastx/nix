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
        name = "Brother-HL-L2340D";
        deviceUri = "ipp://100.64.218.104:631/printers/Brother-HL-L2340D";
        model = "everywhere";
        ppdOptions.PageSize = "A4";
      }
    ];
    ensureDefaultPrinter = "Brother-HL-L2340D";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
  };
}
