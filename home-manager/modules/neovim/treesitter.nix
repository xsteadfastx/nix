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
          gitcommit
          lua
          nix
          query
          vim
          vimdoc
          css
          html
          javascript
          json
          toml
          tsx
          typescript
          yaml
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
          dockerfile
          markdown
          markdown_inline
          sql
          terraform
        ]
      ))
    ];
    initLua =
      # lua
      ''
        require("treesitter-context").setup({
            max_lines = 3,
        })

        vim.api.nvim_create_autocmd({ "FileType", "BufReadPost" }, {
          callback = function(args)
            local bufnr = args.buf
            local ft = vim.bo[bufnr].filetype
            if ft == "" or ft == "fzf" then return end

            -- Check file size using modern vim.uv
            local max_filesize = 1024 * 1024
            local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(bufnr))
            if ok and stats and stats.size > max_filesize then
              return
            end

            -- Safe check for parser existence to avoid the "assert" error
            local lang = vim.treesitter.language.get_lang(ft) or ft
            local has_parser = pcall(vim.treesitter.language.inspect, lang)

            if has_parser then
              pcall(vim.treesitter.start, bufnr, lang)
            end
          end,
        })

        local dracula = require("dracula")
        dracula.setup({ italic_comment = true })
        vim.cmd("colorscheme dracula")

        -- Custom Highlighting Groups
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
          ["@variable.member"]    = { fg = c.cyan },
        }

        for group, settings in pairs(hls) do
          vim.api.nvim_set_hl(0, group, settings)
        end
      '';
  };
}
