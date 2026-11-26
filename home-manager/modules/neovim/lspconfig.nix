{ pkgs, ... }:

{
  programs.neovim = {
    extraPackages = with pkgs.unstable; [
      bash-language-server
      buf
      cargo
      cook-cli # `cook lsp` — Cooklang language server
      gopls
      lua-language-server
      nixd
      nixfmt
      pkgs.golangci-lint-langserver
      pkgs.python3Packages.python-lsp-server
      rust-analyzer
      rustc
      typos
      typos-lsp
      vscode-langservers-extracted
      yaml-language-server
    ];
    plugins = with pkgs.unstable.vimPlugins; [
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
        		-- Only map what this client can do: typos_lsp attaches to every
        		-- buffer but has no hover, so a markdown file errored on <Leader>ho.
        		if client:supports_method("textDocument/hover") then
        			vim.keymap.set("n", "<Leader>ho", vim.lsp.buf.hover, opts)
        		end
        		if client:supports_method("textDocument/definition") then
        			vim.keymap.set("n", "<Leader>gd", vim.lsp.buf.definition, opts)
        		end
        		if client:supports_method("textDocument/rename") then
        			vim.keymap.set("n", "<Leader>rn", vim.lsp.buf.rename, opts)
        		end
        	end,
        })

        -- Language Server Configurations

        -- Lua
        vim.lsp.config("lua_ls", {
        	capabilities = capabilities,
        })
        vim.lsp.enable("lua_ls")

        -- Nix. nixd instead of nil: nil only infers types, nixd can evaluate
        -- option trees, so hover on `services.*` / `programs.*` shows the real
        -- description and default, not just a type signature.
        --
        -- The exprs are built per workspace in `before_init` (not baked in at
        -- build time): the flake comes from the workspace root and the host
        -- from `hostname`, so this file stays portable and never points at a
        -- frozen /nix/store copy or someone else's checkout. A workspace that
        -- is not a flake just fails to evaluate -- nixd drops the provider and
        -- keeps working with types only.
        vim.lsp.config("nixd", {
        	capabilities = capabilities,
        	settings = {
        		nixd = {
        			formatting = { command = { "nixfmt" } },
        		},
        	},
        	before_init = function(_, config)
        		local root = config.root_dir
        		if not root then
        			return
        		end
        		local flake = string.format('(builtins.getFlake "%s")', root)
        		local host = string.format("%s.nixosConfigurations.%s", flake, vim.fn.hostname())
        		config.settings.nixd.nixpkgs = { expr = "import " .. flake .. ".inputs.nixpkgs { }" }
        		config.settings.nixd.options = {
        			nixos = { expr = host .. ".options" },
        			home_manager = {
        				expr = host .. ".options.home-manager.users.type.getSubOptions []",
        			},
        		}
        	end,
        })
        vim.lsp.enable("nixd")

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

        -- Cooklang (`cook lsp`, from cookcli). Neovim has no built-in .cook
        -- filetype, so register it before enabling the server.
        vim.filetype.add({ extension = { cook = "cook" } })
        vim.lsp.config("cooklang", {
        	cmd = { "cook", "lsp" },
        	filetypes = { "cook" },
        	root_markers = { ".git" },
        	capabilities = capabilities,
        })
        vim.lsp.enable("cooklang")

        -- Bulk enable generic servers
        local generic_servers = {
        	"bashls",
        	"buf_ls",
        	"golangci_lint_ls",
        	"pylsp",
        	"rust_analyzer",
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
