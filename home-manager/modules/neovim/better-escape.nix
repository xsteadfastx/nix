{ pkgs, ... }:

{
  programs.neovim = {
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
