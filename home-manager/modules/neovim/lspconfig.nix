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
        -- nixd resolves options against one flake attribute, so pinning it to
        -- this machine gives wrong hovers, completions and go-to-definition while
        -- editing another host's file. The host follows the buffer -- and only if
        -- `hosts/<name>/` is a real host in this tree, since a typo'd path would
        -- otherwise make nixd drop the option provider entirely; else this
        -- machine. Packages come from the host's own `pkgs`, not
        -- `import inputs.nixpkgs { }`: only the former has this repo's overlays,
        -- so `pkgs.unstable.*` resolves.
        --
        -- Same shape as jdguillot/.dotfiles and joshan-kana/.files; the
        -- `git+file://` ref is 5n7/dotfiles' trick -- Nix otherwise snapshots the
        -- whole tree into the store on every re-evaluation (measured here: 1.3s
        -- vs 0.7s), and a dirty tree is fine because nixd evaluates impurely.
        local function nixd_host(root)
        	local name = vim.api.nvim_buf_get_name(0):match("/hosts/([^/]+)/")
        	if name and root and vim.uv.fs_stat(("%s/hosts/%s/default.nix"):format(root, name)) then
        		return name
        	end
        	return vim.fn.hostname()
        end

        local function nixd_settings(host, root)
        	local ref = vim.uv.fs_stat(root .. "/.git") and "git+file://" .. root or root
        	local system = string.format('(builtins.getFlake %q).nixosConfigurations.%q', ref, host)
        	return {
        		nixpkgs = { expr = system .. ".pkgs" },
        		options = {
        			nixos = { expr = system .. ".options" },
        			home_manager = {
        				expr = system .. ".options.home-manager.users.type.getSubOptions []",
        			},
        		},
        		host = host,
        	}
        end

        vim.lsp.config("nixd", {
        	capabilities = capabilities,
        	settings = {
        		nixd = {
        			formatting = { command = { "nixfmt" } },
        		},
        	},
        	before_init = function(_, config)
        		if not config.root_dir then
        			return
        		end
        		config.settings.nixd = vim.tbl_extend(
        			"force",
        			config.settings.nixd,
        			nixd_settings(nixd_host(config.root_dir), config.root_dir)
        		)
        	end,
        })
        vim.lsp.enable("nixd")

        -- Another host's files in the same session: re-point the running client
        -- and let nixd re-pull its config -- `workspace/didChangeConfiguration`
        -- re-evaluates every provider (Controller::onDidChangeConfiguration), so
        -- the server does not need a restart.
        vim.api.nvim_create_autocmd("BufEnter", {
        	pattern = "*.nix",
        	callback = function()
        		local client = vim.lsp.get_clients({ name = "nixd" })[1]
        		if not client or not client.config.root_dir then
        			return
        		end
        		local host = nixd_host(client.config.root_dir)
        		if client.settings.nixd.host == host then
        			return
        		end
        		client.settings.nixd = vim.tbl_extend(
        			"force",
        			client.settings.nixd,
        			nixd_settings(host, client.config.root_dir)
        		)
        		client:notify("workspace/didChangeConfiguration", { settings = client.settings })
        	end,
        })

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
