{
  pkgs,
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
    plugins = with pkgs.unstable.vimPlugins; [
      conform-nvim
    ];
    extraPackages = with pkgs.unstable; [
      black
      clang-tools
      golines
      hclfmt
      nixfmt
      prettier
      shfmt
      sql-formatter
      stylua
      yamlfmt
    ];
    initLua =
      # lua
      ''
        vim.api.nvim_create_autocmd("BufWritePre", {
        	pattern = "*",
        	callback = function(args)
        		require("conform").format({ bufnr = args.buf })
        	end,
        	group = vim.api.nvim_create_augroup("format", { clear = true }),
        })

        local conform = require("conform")

        conform.formatters.clang_format = {
        	prepend_args = {
        		"-style={BasedOnStyle: Google, IndentWidth: 4, AlignConsecutiveDeclarations: true, AlignConsecutiveAssignments: true, ColumnLimit: 0}",
        	},
        }

        conform.formatters.golines = {
        	prepend_args = { "--base-formatter=gofumpt" },
        }

        conform.formatters.injected = {
        	options = {
        		ignore_errors = false,
        	},
        }

        conform.setup({
        	formatters_by_ft = {
        		go = { "golines" },
        		hcl = { "hcl" },
        		js = { "prettier" },
        		lua = { "stylua", "injected" },
        		markdown = { "prettier", "injected" },
        		nix = { "nixfmt", "injected" },
        		proto = { "clang_format" },
        		python = { "black" },
        		sh = { "shfmt" },
        		sql = { "sqlfluff" },
        		taskfile = { "prettier" },
        		yaml = { "yamlfmt" },
        	},

        	format_on_save = {
        		lsp_format = "fallback",
        		timeout_ms = 50000,
        	},
        })'';
  };
}
