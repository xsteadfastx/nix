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
        -- is already an Obsidian vault. Notes stay flat and keep their names (no
        -- zettel ids). Frontmatter is on, but only properties with a value are
        -- written: the default function also emits `aliases: []` and `tags: []`
        -- on every note, which is noise when neither is used.
        require("obsidian").setup({
          workspaces = { { name = "notes", path = "~/permanent/vimwiki" } },
          picker = { name = "fzf-lua" },
          note_id_func = require("obsidian.builtin").title_id,
          frontmatter = {
            enabled = true,
            -- The built-in function also writes empty `aliases: []` / `tags: []`
            -- on every note; this keeps the block to what is actually set.
            func = function(note)
              local props = { id = note.id }
              if #note.aliases > 0 then props.aliases = note.aliases end
              if #note.tags > 0 then props.tags = note.tags end
              return vim.tbl_extend("force", props, note.metadata or {})
            end,
          },
          ui = { enable = false },
          daily_notes = { enabled = false },
          legacy_commands = false,
        })

        local actions = require("obsidian.actions")

        -- Note actions work from any buffer, so map them globally: leaving them
        -- in the markdown FileType autocmd below made them a silent no-op
        -- everywhere else (empty buffer, code, terminal).
        vim.keymap.set("n", "<Leader>nn", "<cmd>Obsidian new<CR>", { desc = "Obsidian new note" })
        vim.keymap.set("n", "<Leader>ns", "<cmd>Obsidian quick_switch<CR>", { desc = "Obsidian switch note" })
        vim.keymap.set("n", "<Leader>nr", "<cmd>Obsidian search<CR>", { desc = "Obsidian search" })

        vim.api.nvim_create_autocmd("FileType", {
          pattern = "markdown",
          callback = function(ev)
            local opts = { buffer = ev.buf }
            -- smart_action only *returns* the command to run, so the mapping
            -- has to be an expr one or its return value is thrown away.
            vim.keymap.set("n", "<CR>", actions.smart_action, vim.tbl_extend("force", opts, { expr = true }))
            vim.keymap.set("n", "<Leader>nb", "<cmd>Obsidian backlinks<CR>", opts)
          end,
        })
      '';
  };
}
