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
      pkgs.python3Packages.python-lsp-server
      typos
      typos-lsp
      vscode-langservers-extracted
      yaml-language-server
    ];
    plugins = with pkgsUnstable.vimPlugins; [
      SchemaStore-nvim
      blink-cmp
      nvim-lspconfig
    ];
    initLua =
      # lua
      ''
        local blink = require("blink.cmp")
        local capabilities = blink.get_lsp_capabilities()

        if capabilities.workspace then
        	capabilities.workspace.didChangeWatchedFiles = {
        		dynamicRegistration = true,
        	}
        end

        vim.lsp.config("*", {
        	capabilities = capabilities,
        })

        -- Border
        local border = "single"

        local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
        function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
        	opts = opts or {}
        	opts.border = opts.border or border
        	return orig_util_open_floating_preview(contents, syntax, opts, ...)
        end

        -- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border })
        -- vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border })

        -- Global LSP attachment callback
        vim.api.nvim_create_autocmd("LspAttach", {
        	callback = function(args)
        		local client = vim.lsp.get_client_by_id(args.data.client_id)
        		if not client then
        			return
        		end

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
        vim.lsp.config("lua_ls", {
        	capabilities = capabilities,
        })
        vim.lsp.enable("lua_ls")

        -- Nix (with formatting)
        vim.lsp.config("nil_ls", {
        	capabilities = capabilities,
        	settings = {
        		["nil"] = {
        			formatting = { command = { "nixfmt" } },
        		},
        	},
        })
        vim.lsp.enable("nil_ls")

        -- Go (with gofumpt)
        vim.lsp.config("gopls", {
        	capabilities = capabilities,
        	settings = {
        		gopls = {
        			gofumpt = true,
        		},
        	},
        })
        vim.lsp.enable("gopls")

        -- JSON (with SchemaStore integration)
        vim.lsp.config("jsonls", {
        	settings = {
        		json = {
        			schemas = require("schemastore").json.schemas(),
        			validate = { enable = true },
        		},
        	},
        })
        vim.lsp.enable("jsonls")

        -- YAML (with SchemaStore and custom filetypes)
        vim.lsp.config("yamlls", {
        	filetypes = { "yaml", "yaml.docker-compose", "taskfile" },
        	settings = {
        		yaml = {
        			schemas = require("schemastore").yaml.schemas(),
        			keyOrdering = false,
        		},
        	},
        })
        vim.lsp.enable("yamlls")

        -- Bulk enable generic servers
        local generic_servers = {
        	"bashls",
        	"buf_ls",
        	"golangci_lint_ls",
        	"pylsp",
        	"typos_lsp",
        }
        for _, lsp in ipairs(generic_servers) do
        	vim.lsp.config(lsp, {
        		capabilities = capabilities,
        	})
        	vim.lsp.enable(lsp)
        end

        -- Diagnostic display settings
        vim.diagnostic.config({
        	virtual_text = true,
        	signs = true,
        	update_in_insert = false,
        	severity_sort = true,
        	float = {
        		border = border,
        		source = "always",
        	},
        })
      '';
  };
}
