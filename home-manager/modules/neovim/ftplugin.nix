{
  nixosConfig,
  lib,
  ...
}:
let
  cfg = nixosConfig.xsfx;

  inherit (lib) mkIf;
in
{
  xdg.configFile = mkIf cfg.neovim {
    "nvim/ftplugin/css.lua".text = ''
      vim.opt.tabstop = 2
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.sopfttabstop = 2
    '';

    "nvim/ftplugin/go.lua".text = ''
      vim.opt.expandtab = false
      vim.opt.tabstop = 4
      vim.opt.shiftwidth = 4
      vim.opt.softtabstop = 4
    '';

    "nvim/ftplugin/html.lua".text = ''
      vim.opt.sw = 2
      vim.opt.ts = 2
      vim.opt.sts = 2
    '';

    "nvim/ftplugin/javascript.lua".text = ''
      vim.opt.tabstop = 2
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.softtabstop = 2
    '';

    "nvim/ftplugin/json.lua".text = ''
      vim.opt.tabstop = 2
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.softtabstop = 2
    '';

    "nvim/ftplugin/markdown.lua".text = ''
      vim.opt.tabstop = 2 
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.softtabstop = 2
    '';

    "nvim/ftplugin/nix.lua".text = ''
      vim.opt.expandtab = true
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.softtabstop = 2
    '';

    "nvim/ftplugin/taskfile.lua".text = ''
      vim.cmd("syntax on")
      vim.opt.tabstop = 2
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.softtabstop = 2
      vim.cmd("setl syntax=yaml")
    '';

    "nvim/ftplugin/tex.lua".text = ''
      vim.opt.tabstop = 4
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 4
      vim.opt.softtabstop = 4
    '';

    "nvim/ftplugin/yaml.lua".text = ''
      vim.opt.tabstop = 2
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.softtabstop = 2
    '';

    "nvim/ftplugin/sh.lua".text = ''
      vim.opt.tabstop = 4
      vim.opt.expandtab = false
      vim.opt.shiftwidth = 4
      vim.opt.softtabstop = 4
    '';
  };

}
