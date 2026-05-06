{
  pkgsUnstable,
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
    plugins = with pkgsUnstable.vimPlugins; [
      better-escape-nvim
    ];
    extraLuaConfig =
      #lua
      ''
        require("better_escape").setup({})
      '';
  };
}
