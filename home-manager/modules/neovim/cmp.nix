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
      blink-cmp
      friendly-snippets
      luasnip
    ];

    extraLuaConfig =
      # lua
      ''
        local ls = require("luasnip")
        require("luasnip.loaders.from_vscode").lazy_load()

        ls.add_snippets("all", {
        	ls.parser.parse_snippet("hw", "hello world!"),
        })

        local blink = require("blink.cmp")

        blink.setup({
        	keymap = {
        		preset = "default",
        		["<C-space>"] = { "show", "fallback" },
        		["<CR>"] = { "accept", "fallback" },
        		["<Tab>"] = { "snippet_forward", "select_next", "fallback" },
        		["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },
        	},

        	appearance = {
        		use_nvim_cmp_as_default = true,
        		nerd_font_variant = "mono",
        	},

        	completion = {
        		menu = {
        			border = "rounded",
        			draw = {
        				columns = {
        					{ "label", "label_description", gap = 1 },
        					{ "kind_icon", "kind", gap = 1 },
        					{ "source_name" },
        				},
        			},
        		},

        		accept = {
        			auto_brackets = { enabled = true },
        		},

        		documentation = {
        			auto_show = true,
        			auto_show_delay_ms = 200,
        			window = { border = "rounded" },
        		},

        		trigger = {
        			show_on_insert = false,
        		},
        	},

        	signature = { enabled = true, window = { border = "rounded" } },

        	cmdline = {
        		enabled = true,
        		sources = function()
        			local type = vim.fn.getcmdtype()
        			if type == "/" or type == "?" then
        				return { "buffer" }
        			end
        			if type == ":" then
        				return { "cmdline", "path" }
        			end
        			return {}
        		end,
        	},

        	sources = {
        		default = { "lsp", "path", "snippets", "buffer" },
        		providers = {
        			lsp = { name = "LSP", score_offset = 10 },
        			path = { name = "Path", score_offset = 5 },
        			snippets = { name = "Snip" },
        			buffer = { name = "Buf" },
        		},
        	},

        	snippets = { preset = "luasnip" },
        })'';
  };
}
