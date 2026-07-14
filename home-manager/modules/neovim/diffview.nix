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
      diffview-nvim
    ];
    initLua =
      #lua
      ''
        require("diffview").setup({
        	default_args = {
        		DiffviewOpen = { "--imply-local" },
        	},
        	hooks = {
        		diff_buf_read = function(bufnr)
        			vim.opt_local.foldenable = false
        		end,
        	},
        })

        vim.keymap.set("n", "<Leader>do", ":DiffviewOpen<CR>")
        vim.keymap.set("n", "<Leader>dc", ":DiffviewClose<CR>")
      '';
  };
}
