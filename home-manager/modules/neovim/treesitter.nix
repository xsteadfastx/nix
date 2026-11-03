{ pkgs, ... }:

{
  programs.neovim = {
    plugins = with pkgs.unstable.vimPlugins; [
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
          cooklang
        ]
      ))
    ];
    initLua =
      # lua
      ''
        require("treesitter-context").setup({
            max_lines = 3,
        })

        -- .cook files use filetype "cook" but the parser is named "cooklang";
        -- map it so the autocmd below resolves the right parser.
        vim.treesitter.language.register("cooklang", "cook")

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

        -- Colours: catppuccin.nvim (home-manager/modules/catppuccin.nix).
        vim.cmd("syntax off")
      '';
  };
}
