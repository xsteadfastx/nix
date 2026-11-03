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

    # swaync's stylesheet hardcodes "Ubuntu Nerd Font"; match the session.
    # Size stays at the port's 14px: 12px Lilex reads thin at ~92 DPI.
    swaync.font = "Lilex Nerd Font";

    # Exceptions, themed by hand from the same sources:
    # - waybar: its `@import` of a store path is not resolved by waybar's GTK
    #   css parser (bar rendered unstyled, 2026-11-02), so
    #   home-manager/modules/waybar inlines the port's palette file instead.
    # - kvantum: the port assumes a blurring compositor; home-manager/modules/gtk
    #   ships a solid variant of the same theme.
    waybar.enable = false;
    kvantum.enable = false;
  };
}
