_: {
  # The theme itself comes from catppuccin.btop (home-manager/modules/catppuccin.nix): it
  # installs btop/themes/catppuccin_<flavor>.theme and points color_theme at it.
  programs.btop = {
    enable = true;
    settings = {
      theme_background = false;
      vim_keys = true;
    };
  };
}
