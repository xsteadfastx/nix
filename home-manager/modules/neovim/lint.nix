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
      markdownlint-cli
      shellcheck
      sqlfluff
      hadolint
      ansible_lint
    ];
    extraLuaConfig = ''
      require("lint").lint.linters.sqlfluff.args = {
        "lint",
        "--format=json",
        "--dialect=postgres",
      }

      require("lint").lint.linters_by_ft = {
        sh = { "shellcheck" },
        ansible = { "ansible_lint" },
        dockerfile = { "hadolint" },
        markdown = { "markdownlint" },
        sql = { "sqlfluff" },
      }

      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*",
        callback = function()
          require("lint").try_lint()
        end,
        group = nvim.api.nvim_create_augroup("lint", { clear = true }),
      })
    '';
  };
}
