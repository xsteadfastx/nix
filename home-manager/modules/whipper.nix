{ pkgs, ... }:
let
  inherit (pkgs) whipper;
in
{
  home.packages = [
    whipper
  ];

  xdg.configFile."whipper/whipper.conf".text = ''
    [drive:ThinkPad%3AUltraslim%20DVD%20%20%20%3APL31]
    vendor = ThinkPad
    model = Ultraslim DVD
    release = PL31
    defeats_cache = True
    read_offset = 6

    [whipper.cd.rip]
    # unknown = True
    output_directory = ~/permanent/syncthing_mediashare
    track_template = new/%%A/%%y - %%d/%%t - %%n
    disc_template =  new/%%A/%%y - %%d/%%A - %%d
  '';
}
