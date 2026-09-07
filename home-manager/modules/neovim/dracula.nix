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
