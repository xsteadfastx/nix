{ pkgs, ... }:

{
  programs.neovim = {
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
