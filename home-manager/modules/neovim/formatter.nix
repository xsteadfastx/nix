{pkgsUnstable, nixosConfig, lib,...}:
let
  cfg = nixosConfig.xsfx;

  inherit (lib) mkIf;
in
{
  programs.neovim = mkIf cfg.neovim {
    plugins = with pkgsUnstable.vimPlugins; [
      conform-nvim
    ];
    extraPackages = with pkgsUnstable;[
      black
      clang-tools
      golines
      hclfmt
      nixfmt-rfc-style
      nodePackages.prettier
      shfmt
      sql-formatter
      stylua
      yamlfmt
    ];
    extraLuaConfig = ''
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*",
        callback = function(args)
          require("conform").format({ bufnr = args.buf })
        end,
        group = vim.api.nvim_create_augroup("format", { clear = true }),
      })

      require("conform").formatters.clang_format = {
        prepend_args = {
          "-style={BasedOnStyle: Google, IndentWidth: 4, AlignConsecutiveDeclarations: true, AlignConsecutiveAssignments: true, ColumnLimit: 0}",
        },
      }

      require("conform").formatters.golines = {
        prepend_args = { "--base-formatter=gofumpt" },
      }

      require("conform").formatters.injected = {
        options = {
          ignore_errors = false,
        },
      }

      require("conform").setup({
        formatters_by_ft = {
          go = { "golines" },
          hcl = { "hcl" },
          js = { "prettier" },
          lua = { "stylua" },
          markdown = { "prettier" },
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
      })
    '';
  };
}
