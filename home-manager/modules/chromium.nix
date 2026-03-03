{
  lib,
  nixosConfig,
  pkgsUnstable,
  ...
}:

let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  programs.chromium = {
    enable = true;
    package = pkgsUnstable.chromium.override { enableWideVine = true; };
    extensions = [
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # dark reader
      { id = "gfapcejdoghpoidkfodoiiffaaibpaem"; } # dracula
      { id = "ddkjiahejlhfcafbddmgiahcphecmpfh"; } # ublock origin lite
      { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # vimium
      { id = "edibdbjcniadpccecjdfdjjppcpchdlm"; } # i still dont care about cookies
      { id = "dhdgffkkebhmkfjojejmpbldmpobfkfo"; } # tampermonkey
    ];
  };
}
