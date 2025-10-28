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
      vscode-langservers-extracted
      yaml-language-server
    ];
    plugins = with pkgsUnstable.vimPlugins; [
      SchemaStore-nvim
      cmp-nvim-lsp
      nvim-lspconfig
    ];
    extraLuaConfig = ''
      -- lsp configuration
      lspconfig = require("lspconfig")

      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      vim.lsp.enable('lua_ls')
      vim.lsp.config('lua_ls', {
        capabilities = capabilities
      })

      vim.lsp.enable('nil_ls')
      vim.lsp.config('nil_ls', {
        capabilities = capabilities,
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
        capabilities = capabilities,
        settings = {
          gopls = {
            gofumpt = true,
          },
        },
      })

      vim.lsp.enable('golangci_lint_ls')
      vim.lsp.config('golangci_lint_ls', {
        capabilities = capabilities,
      })

      vim.lsp.enable('jsonls')
      vim.lsp.config('jsonls', {
        capabilities = capabilities,
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      })

      vim.lsp.enable('yamlls')
      vim.lsp.config('yamlls', {
        capabilities = capabilities,
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
        capabilities = capabilities,
      })

      vim.lsp.enable('bashls')
      vim.lsp.config('bashls', {
        capabilities = capabilities,
      })

      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
        border = "single",
      })

      vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
        border = "single",
      })

      -- vim.diagnostic.config({ virtual_text = true })

      vim.keymap.set("n", "<Leader>ho", "<cmd>lua vim.lsp.buf.hover({border = 'single'})<CR>")
      vim.keymap.set("n", "<Leader>gd", "<cmd>lua vim.lsp.buf.definition()<CR>")
      vim.keymap.set("n", "<Leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>" )
    '';
  };
}
