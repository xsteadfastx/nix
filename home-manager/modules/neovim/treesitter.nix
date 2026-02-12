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
      nvim-lspconfig

      (nvim-treesitter.withPlugins (
        p: with p; [
          # Core / Config
          gitcommit
          lua
          nix
          query # Required for treesitter inspections
          vim
          vimdoc

          # Web Development
          css
          html
          javascript
          json
          toml
          tsx
          typescript
          yaml

          # Programming Languages
          bash
          c
          cpp
          go
          gomod
          gosum
          gowork
          proto
          python
          rust

          # Documentation / Markup
          dockerfile
          markdown
          markdown_inline
          sql
          terraform
        ]
      ))
    ];
    extraLuaConfig =
      # lua
      ''
        require("treesitter-context").setup({
            max_lines = 3, -- Keep small to prevent lag on scroll
        })

        vim.api.nvim_create_autocmd({ "FileType", "BufReadPost" }, {
          callback = function(args)
            local bufnr = args.buf
            -- Optimization: Don't start for large files
            local max_filesize = 1024 * 1024
            local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(bufnr))
            if ok and stats and stats.size > max_filesize then
              return
            end

            -- Check if we have a parser for the current language
            local ft = vim.bo[bufnr].filetype
            local lang = vim.treesitter.language.get_lang(ft) or ft

            -- Try to start the native treesitter highlighting
            local has_parser, _ = pcall(vim.treesitter.get_parser, bufnr, lang)
            if has_parser then
              vim.treesitter.start(bufnr, lang)
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
      '';
  };
}
