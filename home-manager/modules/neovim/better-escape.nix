{
  pkgs,
  nixosConfig,
  lib,
  ...
}:
let
  cfg = nixosConfig.features;

  inherit (lib) mkIf;
in
{
  programs.neovim = mkIf cfg.neovim {
    plugins = with pkgs.unstable.vimPlugins; [
      better-escape-nvim
    ];
    initLua =
      #lua
      ''
        require("better_escape").setup({})
      '';
  };
}
