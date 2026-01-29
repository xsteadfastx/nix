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
      buf
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
      -- Border
      local border = "single"

      local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
      function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
        opts = opts or {}
        opts.border = opts.border or border
        return orig_util_open_floating_preview(contents, syntax, opts, ...)
      end

      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
        vim.lsp.handlers.hover, { border = border }
      )
      vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
        vim.lsp.handlers.signature_help, { border = border }
      )

      -- Global LSP attachment callback
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then return end

          -- Disable semantic tokens to prioritize Treesitter highlighting and save CPU
          if client.server_capabilities then
            client.server_capabilities.semanticTokensProvider = nil
          end

          -- LSP Keybindings
          local opts = { buffer = args.buf }
          vim.keymap.set("n", "<Leader>ho", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<Leader>gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "<Leader>rn", vim.lsp.buf.rename, opts)
        end,
      })

      -- Language Server Configurations

      -- Lua
      vim.lsp.enable('lua_ls')

      -- Nix (with formatting)
      vim.lsp.enable('nil_ls')
      vim.lsp.config('nil_ls', {
        settings = {
          ["nil"] = {
            formatting = { command = { "nixfmt" } },
          },
        },
      })

      -- Go (with gofumpt)
      vim.lsp.enable('gopls')
      vim.lsp.config('gopls', {
        settings = {
          gopls = { gofumpt = true },
        },
      })

      -- JSON (with SchemaStore integration)
      vim.lsp.enable('jsonls')
      vim.lsp.config('jsonls', {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      })

      -- YAML (with SchemaStore and custom filetypes)
      vim.lsp.enable('yamlls')
      vim.lsp.config('yamlls', {
        filetypes = { "yaml", "yaml.docker-compose", "taskfile" },
        settings = {
          yaml = {
            schemas = require("schemastore").yaml.schemas(),
            keyOrdering = false,
          },
        },
      })

      -- Bulk enable generic servers
      local generic_servers = {
        "golangci_lint_ls",
        "pylsp",
        "bashls",
        "typos_lsp",
        "buf_ls"
      }
      for _, lsp in ipairs(generic_servers) do
        vim.lsp.enable(lsp)
      end

      -- Diagnostic display settings
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        update_in_insert = false, -- Only recalculate diagnostics when leaving insert mode
        severity_sort = true,
        float = { border = border },
      })
    '';
  };
}
