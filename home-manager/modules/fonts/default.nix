{ nixosConfig, lib, ... }:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  home.file.".local/share/fonts" = {
    source = ./fonts;
    recursive = true;
  };
}
