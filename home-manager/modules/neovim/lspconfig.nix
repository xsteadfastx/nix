{
  pkgs,
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
    extraPackages = with pkgsUnstable; [
      bash-language-server
      gopls
      lua-language-server
      nil
      pkgs.golangci-lint-langserver
      python312Packages.python-lsp-server
      typos
      typos-lsp
      vscode-langservers-extracted
      yaml-language-server
    ];
    plugins = with pkgsUnstable.vimPlugins; [
      SchemaStore-nvim
      nvim-lspconfig
    ];
    extraLuaConfig = ''
      -- lsp configuration
      lspconfig = require("lspconfig")

      vim.lsp.enable('lua_ls')
      vim.lsp.config('lua_ls', {
      })

      vim.lsp.enable('nil_ls')
      vim.lsp.config('nil_ls', {
        settings = {
          ["nil"] = {
            formatting = {
              command = { "nixfmt" },
            },
          },
        },
      })

      vim.lsp.enable('gopls')
      vim.lsp.config('gopls', {
        settings = {
          gopls = {
            gofumpt = true,
          },
        },
      })

      vim.lsp.enable('golangci_lint_ls')
      vim.lsp.config('golangci_lint_ls', {
      })

      vim.lsp.enable('jsonls')
      vim.lsp.config('jsonls', {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      })

      vim.lsp.enable('yamlls')
      vim.lsp.config('yamlls', {
        settings = {
          schemaStore = {
            enable = false,
            url = "",
          },
          yaml = {
            schemas = require("schemastore").yaml.schemas(),
            keyOrdering = false,
          },
        },
        filetypes = { "yaml", "yaml.docker-compose", "taskfile" },
      })

      vim.lsp.enable('pylsp')
      vim.lsp.config('pylsp', {
      })

      vim.lsp.enable('bashls')
      vim.lsp.config('bashls', {
      })

      vim.lsp.enable('typos_lsp')
      vim.lsp.config('typos_lsp', {
      })

      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
        border = "single",
      })

      vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
        border = "single",
      })

      vim.diagnostic.config({
        virtual_text = true;
        signs = true;
        update_in_insert = false;
        severity_sport = true;
      })

      vim.keymap.set("n", "<Leader>ho", "<cmd>lua vim.lsp.buf.hover({border = 'single'})<CR>")
      vim.keymap.set("n", "<Leader>gd", "<cmd>lua vim.lsp.buf.definition()<CR>")
      vim.keymap.set("n", "<Leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>" )
    '';
  };
}
