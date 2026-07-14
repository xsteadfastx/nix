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
mkIf cfg.neovim {
  programs.neovim = {
    plugins = with pkgs.unstable.vimPlugins; [
      otter-nvim
    ];
    initLua =
      #lua
      ''
        local otter = require('otter')

        otter.setup({
          lsp = { diagnostic_update_events = { "BufWritePost" } },
          buffers = { set_filetype = true },
        })

        local supported_langs = { "lua", "python", "bash", "go", "cpp", "nix" }

        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(args)
            local ft = vim.bo[args.buf].filetype
            if ft == "markdown" or ft == "nix" then
              vim.schedule(function()
                if vim.api.nvim_buf_is_valid(args.buf) then
                  otter.activate(supported_langs)
                end
              end)
            end
          end,
        })
      '';
  };
}
