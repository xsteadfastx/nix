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
      dracula-nvim
      nvim-treesitter-context
      nvim-treesitter.withAllGrammars
    ];
    extraLuaConfig = lib.mkAfter ''
      require("treesitter-context").setup()

      local dracula = require("dracula")

      local colors = dracula.colors()

      local hls = {
        ["@variable"]           = { fg = colors.fg },
        ["@parameter"]          = { fg = colors.orange, italic = true },
        ["@function"]           = { fg = colors.green, bold = true },
        ["@keyword"]            = { fg = colors.pink },
        ["@lsp.type.variable"]  = { fg = colors.fg },
        ["@lsp.type.parameter"] = { fg = colors.orange, italic = true },
      }
      for group, settings in pairs(hls) do
        vim.api.nvim_set_hl(0, group, settings)
      end
    '';
  };
}
