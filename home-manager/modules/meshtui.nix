{
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features.meshcore;
in
lib.mkIf cfg {
  # two complete, independent MeshCore TUIs, both installed. meshtui and
  # meshtui2 ship the same python module, so they must NOT have their full
  # output trees merged into the profile (lib/ collision). The overlay exposes
  # each as `meshtuiProfile`/`meshtui2Profile` = bin-only entries, so they
  # coexist and are interchangeable:
  #   meshtui -s /dev/ttyUSB0
  #   meshtui2 -p /dev/ttyUSB0 --protocol meshcore
  home.packages = [
    pkgs.meshtuiProfile
    pkgs.meshtui2Profile
  ];
}
