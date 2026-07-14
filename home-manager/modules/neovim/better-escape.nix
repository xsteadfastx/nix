{
  pkgs,
  nixosConfig,
  lib,
  ...
}:
let
  cfg = nixosConfig.xsfx;

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
