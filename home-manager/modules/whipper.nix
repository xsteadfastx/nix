{ pkgs, ... }:
let
  # cdrdao's slow read-toc (Q-subchannel pregap scan) mangles the TOC on some
  # drives, so whipper dies with discid's "Disc too long" / "Invalid order".
  # Fall back to the fast TOC instead of failing the whole rip (that is what
  # upstream would want anyway; the slow pass only adds INDEX 00 detail).
  # https://github.com/whipper-team/whipper/issues/583
  whipper = pkgs.whipper.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./whipper-fast-toc-fallback.patch ];
  });
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
