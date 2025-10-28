{
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
    extraLuaConfig = ''
      local opt = vim.opt -- to set options

      opt.number = true -- numbers on the side
      opt.relativenumber = true -- ralative line numbers
      opt.backspace = "2"
      opt.laststatus = 2
      opt.synmaxcol = 120
      -- opt.cursorline = true

      -- marks for file characters in the document
      -- opt.listchars:append({ eol = "↴" })
      -- opt.listchars:append({ trail = "-" })
      -- opt.listchars:append({ nbsp = "+" })
      -- opt.listchars:append({ extends = ">" })
      -- opt.listchars:append({ precedes = "<" })
      -- opt.listchars:append({ space = "⋅" })

      opt.background = "dark"
      opt.list = true -- show some hidden characters
      opt.termguicolors = true -- true color support
      opt.foldenable = false -- disable initional folding
      opt.foldmethod = "syntax"

      opt.autoindent = true
      opt.smartindent = true
      opt.wrap = false

      opt.hlsearch = false -- no highlights for search

      -- folding
      opt.foldmethod = "expr"
      opt.foldexpr = "nvim_treesitter#foldexpr()"

      -- no info msg
      opt.shortmess = "I"
    '';
  };
}
