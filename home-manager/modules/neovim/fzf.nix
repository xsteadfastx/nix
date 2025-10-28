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
      fzf-lua
      nvim-web-devicons
    ];
    extraPackages = with pkgsUnstable; [
      fd
      fzf
      ripgrep
    ];
    extraLuaConfig = ''
      require("fzf-lua").setup({
        winopts = {
          fullscreen = true,
        },
        files = {
          fd_opts = "--color=always --type f --hidden --no-ignore --follow --exclude .git --exclude vendor --exclude .cache --exclude .direnv --exclude result",
        },
        grep = {
          rg_opts = "--no-ignore-vcs --hidden --column --line-number --no-heading --color=always --smart-case --max-columns=512 -g '!vendor/*' -g '!.git/*' -g '!.direnv/*' -g '!result/*'",
        },
      })

      vim.keymap.set("n", "<Leader><space>", "<cmd>lua require('fzf-lua').buffers()<CR>")
      vim.keymap.set("n", "<Leader>tt", "<cmd>lua require('fzf-lua').tabs()<CR>")
      vim.keymap.set("n", "<Leader>ff", "<cmd>lua require('fzf-lua').files()<CR>")
      vim.keymap.set("n", "<Leader>rg", "<cmd>lua require('fzf-lua').grep_project()<CR>")
      vim.keymap.set("n", "<Leader>ll", "<cmd>lua require('fzf-lua').grep_curbuf()<CR>")
      vim.keymap.set("n", "<Leader>cm", "<cmd>lua require('fzf-lua').git_commits()<CR>")
      vim.keymap.set("n", "<Leader>cf", "<cmd>lua require('fzf-lua').git_bcommits()<CR>")
      vim.keymap.set("n", "<Leader>:", "<cmd>lua require('fzf-lua').commands()<CR>")
      vim.keymap.set("n", "<Leader>fr", "<cmd>lua require('fzf-lua').lsp_references()<CR>")
    '';
  };
}
