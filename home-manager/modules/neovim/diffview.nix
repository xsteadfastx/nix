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
      diffview-nvim
    ];
    extraLuaConfig =
      #lua
      ''
        vim.keymap.set("n", "<Leader>do", ":DiffviewOpen<CR>")
        vim.keymap.set("n", "<Leader>dc", ":DiffviewClose<CR>")
      '';
  };
}
