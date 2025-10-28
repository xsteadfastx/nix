{pkgsUnstable, nixosConfig, lib,...}:
let
  cfg = nixosConfig.xsfx;

  inherit (lib) mkIf mkBefore;
in
{
  programs.neovim = mkIf cfg.neovim {
    extraLuaConfig = mkBefore ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = "\\"

      vim.keymap.set("", "<Up>", "<Nop>")
      vim.keymap.set("", "<Down>", "<Nop>")
      vim.keymap.set("", "<Left>", "<Nop>")
      vim.keymap.set("", "<Right>", "<Nop>")

      -- center line
      vim.keymap.set("n", "j", "jzz")
      vim.keymap.set("n", "k", "kzz")

      -- fixes some strange arrow errors in insert mode
      vim.keymap.set("i", "^[OA", "<ESC>kli")
      vim.keymap.set("i", "^[OB", "<ESC>jli")
      vim.keymap.set("i", "^[OC", "<ESC>lli")
      vim.keymap.set("i", "^[OD", "<ESC>hli")

      -- better indentation
      vim.keymap.set("v", "<", "<gv")
      vim.keymap.set("v", ">", ">gv")

      -- force tab
      vim.keymap.set("i", "<S-Tab>", "<C-V><Tab>")

      -- buffers
      -- should be delivered through barbar or moll/vim-bbye
      vim.keymap.set("n", "<A-,>", ":TablineBufferPrevious<CR>")
      vim.keymap.set("n", "<A-.>", ":TablineBufferNext<CR>")
      vim.keymap.set("n", "<A-c>", ":bd<CR>")

      -- terminal mode
      vim.keymap.set("t", "<Leader><Esc>", "<C-\\><C-n>")
    '';
  };
}
