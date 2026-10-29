{ pkgs, ... }:

{
  programs.neovim = {
    plugins = with pkgs.unstable.vimPlugins; [
      obsidian-nvim
    ];

    initLua =
      # lua
      ''
        -- ~/permanent/vimwiki is a plain markdown vault with [[wiki links]], so it
        -- is already an Obsidian vault. Notes stay flat, keep their names (no
        -- zettel ids), and get no frontmatter, so existing files are untouched.
        require("obsidian").setup({
          workspaces = { { name = "notes", path = "~/permanent/vimwiki" } },
          picker = { name = "fzf-lua" },
          note_id_func = require("obsidian.builtin").title_id,
          frontmatter = { enabled = false },
          ui = { enable = false },
          daily_notes = { enabled = false },
          legacy_commands = false,
        })

        local actions = require("obsidian.actions")

        vim.api.nvim_create_autocmd("FileType", {
          pattern = "markdown",
          callback = function(ev)
            local opts = { buffer = ev.buf }
            -- smart_action only *returns* the command to run, so the mapping
            -- has to be an expr one or its return value is thrown away.
            vim.keymap.set("n", "<CR>", actions.smart_action, vim.tbl_extend("force", opts, { expr = true }))
            vim.keymap.set("n", "<Leader>nn", "<cmd>Obsidian new<CR>", opts)
            vim.keymap.set("n", "<Leader>ns", "<cmd>Obsidian quick_switch<CR>", opts)
            vim.keymap.set("n", "<Leader>nb", "<cmd>Obsidian backlinks<CR>", opts)
            vim.keymap.set("n", "<Leader>nr", "<cmd>Obsidian search<CR>", opts)
          end,
        })
      '';
  };
}
