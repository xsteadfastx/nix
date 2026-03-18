{
  lib,
  nixosConfig,
  pkgsUnstable,
  ...
}:
let
  cfg = nixosConfig.xsfx;

  inherit (lib) mkIf;
in
{
  imports = [
    ./augroups.nix
    ./cmp.nix
    ./diffview.nix
    ./dracula.nix
    ./formatter.nix
    ./ftplugin.nix
    ./fzf.nix
    ./keymaps.nix
    ./lint.nix
    ./lspconfig.nix
    ./misc-plugins.nix
    ./otter.nix
    ./treesitter.nix
    ./trouble.nix
    ./ui.nix
    ./vimwiki.nix
  ];

  programs.neovim = mkIf cfg.neovim {
    enable = true;
    package = pkgsUnstable.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    extraLuaConfig =
      #lua
      ''
        vim.cmd("set clipboard+=unnamedplus")
        vim.opt.hidden = true

        vim.g.netrw_liststyle = 3
        vim.g.netrw_banner = 0
        vim.g.netrw_winsize = 25

        vim.opt.swapfile = false

        vim.cmd("filetype indent on")
      '';
  };
}
