{ pkgs, ... }:

{
  programs.neovim = {
    plugins = with pkgs.unstable.vimPlugins; [
      nvim-lint
    ];

    extraPackages = [
      pkgs.unstable.ansible-lint
      pkgs.unstable.hadolint
      pkgs.unstable.markdownlint-cli
      pkgs.sqlfluff
      pkgs.unstable.shellcheck
      pkgs.unstable.statix
    ];

    initLua =
      # lua
      ''
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
