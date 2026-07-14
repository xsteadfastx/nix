{
  pkgs,
  lib,
  nixosConfig,
  ...
}:

let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  programs.chromium = {
    enable = true;
    package = pkgs.unstable.chromium.override { enableWideVine = true; };
    commandLineArgs = [
      "--audio-buffer-size=4096"
    ];
    extensions = [
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # dark reader
      { id = "gfapcejdoghpoidkfodoiiffaaibpaem"; } # dracula
      { id = "ddkjiahejlhfcafbddmgiahcphecmpfh"; } # ublock origin lite
      { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # vimium
      { id = "edibdbjcniadpccecjdfdjjppcpchdlm"; } # i still dont care about cookies
      { id = "dhdgffkkebhmkfjojejmpbldmpobfkfo"; } # tampermonkey
      { id = "mmlmfjhmonkocbjadbfplnigmagldckm"; } # playwright mcp (extension mode)
    ];
  };
}
