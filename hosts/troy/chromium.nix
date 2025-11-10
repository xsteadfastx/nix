{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.xsfx;
in
lib.mkIf cfg.x11 {
  programs.chromium = {
    enable = true;
    extensions = [
      "eimadpbcbfnmbkopoojfekhnkhdbieeh;https://clients2.google.com/service/update2/crx" # dark reader
      "gfapcejdoghpoidkfodoiiffaaibpaem;https://clients2.google.com/service/update2/crx" # dracula
      "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx" # ublock origin lite
      "dbepggeogbaibhgnhhndojpepiihcmeb;https://clients2.google.com/service/update2/crx" # vimium
      "fihnjjcciajhdojfnbdddfaoknhalnja;https://clients2.google.com/service/update2/crx" # i dont care about cookies
    ];
  };

  environment.systemPackages = with pkgs; [
    (chromium.override { enableWideVine = true; })
  ];
}
