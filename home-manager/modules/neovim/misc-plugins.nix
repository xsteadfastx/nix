{
  pkgsUnstable,
  nixosConfig,
  lib,
  ...
}:
let
  cfg = nixosConfig.xsfx;

  inherit (lib) mkIf;

  blame-nvim = pkgsUnstable.vimUtils.buildVimPlugin {
    name = "blame-nvim";
    src = pkgsUnstable.fetchFromGitHub {
      owner = "FabijanZulj";
      repo = "blame.nvim";
      rev = "b87b8c820e4cec06fbbd2f946b7b35c45906ee0c";
      hash = "sha256-v4ieZ7NIWP1khvrcyzTSGX6IHHn0kjZICbyRqS2xqHM=";
    };
  };
in
{
  programs.neovim = mkIf cfg.neovim {
    plugins = with pkgsUnstable.vimPlugins; [
      blame-nvim
      comment-nvim
      csv-vim
      fidget-nvim
      follow-md-links-nvim
      gitsigns-nvim
      indent-blankline-nvim
      lexima-vim
      lualine-nvim
      markid
      mini-icons
      neoscroll-nvim
      nvim-colorizer-lua
      nvim-cursorline
      plenary-nvim
      rainbow-delimiters-nvim
      render-markdown-nvim
      snacks-nvim
      tabline-nvim
      todo-comments-nvim
      vim-better-whitespace
      vim-bracketed-paste
      vim-pencil
      vim-surround
      vim-table-mode
      which-key-nvim
    ];
    extraLuaConfig = ''
      -- nvim-colorizer-lua
      require("colorizer").setup()

      -- lexima-vim
      vim.g.lexima_enable_basic_rules = 1
      vim.g.lexima_enable_newline_rules = 1

      -- lualine-nvim
      require("lualine").setup({
        options = {
          theme = "dracula-nvim",
          },
      })

      -- tabline-nvim
      require("tabline").setup({enable=true})

      -- vim-pencil
      vim.g["pencil#wrapModeDefault"] = "soft"

      vim.api.nvim_create_autocmd("Filetype", {
        pattern = "tex,markdown,mkd,vimwiki",
        callback = function()
          vim.cmd("call pencil#init()")
        end,
        group = vim.api.nvim_create_augroup("pencil", { clear = true })
      })

      -- csv-vim
      vim.b.csv_arrange_use_all_rows = 1

      -- gitsigns-nvim
      require('gitsigns').setup()

      -- comment-nvim
      require('Comment').setup()

      -- neoscroll-nvim
      require("neoscroll").setup()

      -- todo-comments
      require("todo-comments").setup()

      -- which-key-nvim
      require("which-key").setup()

      -- fidget-nvim
      require("fidget").setup()

      -- mini-icons
      require('mini.icons').setup()

      -- nvim-cursorline
      require("nvim-cursorline").setup({
        cursorline = { enable = true, timeout = 500 },
        cursorword = { enable = true, min_length = 3, hl = { underline = true } },
      })

      -- rainbow-delimiters-nvim
      require('rainbow-delimiters.setup').setup()

      -- indent-blankline
      require("ibl").setup()

      -- render-markdown-nvim
      require('render-markdown').setup()

      -- blame-nvim
      require("blame").setup({blame_options={"-w"}})
    '';
  };
}
