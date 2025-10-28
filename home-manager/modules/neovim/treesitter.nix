{pkgsUnstable, nixosConfig, lib,...}:
let
  cfg = nixosConfig.xsfx;

  inherit (lib) mkIf;
in
{
  programs.neovim = mkIf cfg.neovim {
    plugins = with pkgsUnstable.vimPlugins; [
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
    ];
    extraLuaConfig = ''
      require("nvim-treesitter.configs").setup({
        highlight = { enable = true },
        indent = { enable = true },
        markid = { enable = true },
      })

      require("treesitter-context").setup()
    '';
  };
}
