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
      dracula-nvim
    ];
    initLua =
      #lua
      ''
        require("dracula").setup({
        italic_comment = true,
        })
        vim.cmd([[colorscheme dracula]])
      '';
  };
}
