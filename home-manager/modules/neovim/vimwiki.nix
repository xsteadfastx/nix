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
      vimwiki
    ];
    extraLuaConfig = ''
      vim.g["vimwiki_list"] = { { path = "~/permanent/vimwiki/", syntax = "markdown", ext = ".md", index = "Home" } }
      vim.g["vimwiki_global_ext"] = 0


      vim.api.nvim_create_autocmd("Filetype", {
        pattern = "vimwiki",
        callback = function()
          vim.cmd("setl tabstop=4 expandtab shiftwidth=4 softtabstop=4")
        end,
        group = vim.api.nvim_create_augroup("wiki", { clear = true }),
      })
    '';
  };
}
