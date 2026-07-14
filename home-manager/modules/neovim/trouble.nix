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
      trouble-nvim
    ];
    initLua =
      #lua
      ''
        require("trouble").setup({
        	auto_open = false,
        	auto_close = true,
        	use_lsp_diagnostic_signs = false,
        })

        vim.keymap.set("n", "<C-t>", "<cmd>Trouble diagnostics toggle<CR>")
      '';
  };
}
