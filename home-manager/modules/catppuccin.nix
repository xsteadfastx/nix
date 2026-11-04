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
    # - waybar: its `@import` of a store path is not resolved by waybar's GTK
    #   css parser (bar rendered unstyled, 2026-11-02), so
    #   home-manager/modules/waybar inlines the port's palette file instead.
    # - kvantum: the port assumes a blurring compositor; home-manager/modules/gtk
    #   ships a solid variant of the same theme.
    # - swaync: the port's stylesheet is a whole file with no hook for extra
    #   rules, and it leaves toggle buttons unstyled (on looks like off), so
    #   home-manager/modules/swaync derives its own from the same source.
    waybar.enable = false;
    kvantum.enable = false;
    swaync.enable = false;
  };
}
