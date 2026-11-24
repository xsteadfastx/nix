{
  inputs,
  nixosConfig,
  ...
}:
# Catppuccin for every program catppuccin/nix has a port for. On/off, flavour
# and accent follow the NixOS side (modules/catppuccin.nix: on with
# features.desktop), so both classes agree.
{
  imports = [ inputs.catppuccin.homeModules.catppuccin ];

  catppuccin = {
    inherit (nixosConfig.catppuccin) enable flavor accent;

    # Port files from Catppuccin's binary cache instead of building them here.
    cache.enable = true;

    # Not covered by `enable` (`useGlobalEnable = false`); home.pointerCursor's
    # name/package come from here.
    cursors.enable = true;

    # Exceptions, themed by hand from the same sources:
    # - kvantum: the port assumes a blurring compositor; home-manager/modules/gtk
    #   ships a solid variant of the same theme.
    # - firefox/librewolf: both ports are the Firefox Color route (theme
    #   extension plus a click in Settings), which cannot be set
    #   declaratively; librewolf.nix installs the static Catppuccin AMO theme
    #   by policy instead.
    kvantum.enable = false;
    firefox.enable = false;
    librewolf.enable = false;
  };
}
