{ lib, nixosConfig, ... }:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  xdg.configFile."i3/config".source = ./config;
}
