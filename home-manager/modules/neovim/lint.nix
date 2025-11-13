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
      nvim-lint
    ];

    extraPackages = with pkgsUnstable; [
      ansible-lint
      hadolint
      markdownlint-cli
      shellcheck
      sqlfluff
      statix
    ];

    extraLuaConfig = ''
      require("lint").linters.sqlfluff.args = {
        "lint",
        "--format=json",
        "--dialect=postgres",
      }

      require("lint").linters_by_ft = {
        ansible = { "ansible_lint" },
        dockerfile = { "hadolint" },
        markdown = { "markdownlint" },
        nix = { "statix" },
        sh = { "shellcheck" },
        sql = { "sqlfluff" },
      }

      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*",
        callback = function()
          require("lint").try_lint()
        end,
        group = vim.api.nvim_create_augroup("lint", { clear = true }),
      })
    '';
  };
}
