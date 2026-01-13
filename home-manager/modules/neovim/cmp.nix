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
      luasnip
    ];

    extraLuaConfig = ''
      local blink = require('blink.cmp')

      blink.setup({
        keymap = {
          preset = 'default',
          ['<CR>'] = { 'accept', 'fallback' },
        },

        appearance = {
          use_nvim_cmp_as_default = true,
          nerd_font_variant = 'mono',
        },

        completion = {
          menu = {
            border = 'rounded',
            draw = {
              columns = {
                { "label", "label_description", gap = 1 },
                { "kind_icon", "kind", gap = 1 },
                { "source_name" },
              },
            },
          },

          documentation = {
            auto_show = true,
            auto_show_delay_ms = 200,
            window = { border = 'rounded' },
          },

          trigger = {
            show_on_insert = true,
          }
        },

        cmdline = {
          enabled = true,
          sources = function()
            local type = vim.fn.getcmdtype()
            if type == '/' or type == '?' then return { 'buffer' } end
            if type == ':' then return { 'cmdline', 'path' } end
            return {}
          end,
        },

        sources = {
          default = { 'lsp', 'path', 'snippets', 'buffer' },
          providers = {
            lsp = { name = "LSP", score_offset = 10 },
            path = { name = "Path", score_offset = 5 },
            snippets = { name = "Snip" },
            buffer = { name = "Buf" },
          },
        },

        snippets = { preset = 'luasnip' },
      })
    '';
  };
}
