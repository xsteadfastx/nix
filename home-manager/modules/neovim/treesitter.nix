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
      nvim-lspconfig
    ];
    extraLuaConfig = lib.mkAfter ''
      require("treesitter-context").setup({
          max_lines = 3, -- Keep small to prevent lag on scroll
      })

      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
          if lang then
            pcall(vim.treesitter.start)
          end
        end,
      })

      local dracula = require("dracula")
      dracula.setup({
        italic_comment = true,
      })
      vim.cmd("colorscheme dracula")

      local c = dracula.colors()

      vim.cmd("syntax off")

      local hls = {
        ["@attribute"]          = { fg = c.green, italic = true },
        ["@boolean"]            = { fg = c.purple },
        ["@constant"]           = { fg = c.purple, bold = true },
        ["@field"]              = { fg = c.cyan },
        ["@function"]           = { fg = c.green, bold = true },
        ["@function.builtin"]   = { fg = c.cyan },
        ["@keyword"]            = { fg = c.pink },
        ["@lsp.type.class"]      = { fg = c.yellow },
        ["@lsp.type.enumMember"] = { fg = c.purple },
        ["@lsp.type.function"]   = { fg = c.green, bold = true },
        ["@lsp.type.macro"]      = { fg = c.pink },
        ["@lsp.type.method"]     = { fg = c.green, bold = true },
        ["@lsp.type.namespace"]  = { fg = c.pink },
        ["@lsp.type.parameter"]  = { fg = c.orange, italic = true },
        ["@lsp.type.property"]   = { fg = c.cyan },
        ["@lsp.type.type"]       = { fg = c.yellow },
        ["@lsp.type.variable"]   = { fg = c.fg },
        ["@lsp.typemod.variable.readonly"] = { fg = c.purple, bold = true },
        ["@method"]             = { fg = c.green },
        ["@module"]             = { fg = c.pink },
        ["@module.go"]           = { fg = c.pink },
        ["@namespace"]          = { fg = c.pink },
        ["@number"]             = { fg = c.purple },
        ["@operator"]           = { fg = c.pink },
        ["@parameter"]          = { fg = c.orange, italic = true },
        ["@property"]           = { fg = c.cyan },
        ["@punctuation"]        = { fg = c.fg },
        ["@string"]             = { fg = c.yellow },
        ["@tag"]                = { fg = c.pink },
        ["@type"]               = { fg = c.yellow },
        ["@type.builtin"]       = { fg = c.yellow, italic = true },
        ["@variable"]           = { fg = c.fg },
        ["@variable.builtin"]   = { fg = c.cyan, italic = true },
        ["@variable.go"]         = { fg = c.fg },
        ["@variable.member"]    = { fg = c.cyan },
        ["@variable.member.go"]  = { fg = c.cyan },
      }

      for group, settings in pairs(hls) do
        vim.api.nvim_set_hl(0, group, settings)
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client then
            client.server_capabilities.semanticTokensProvider = nil
          end
        end,
      })
    '';
  };
}
