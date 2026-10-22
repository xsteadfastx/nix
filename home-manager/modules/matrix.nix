{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  # iamb config -> ~/.config/iamb/config.toml (see https://iamb.chat/configure.html)
  # Defined as Nix attrs; `pkgs.formats.toml` serializes to TOML.
  iambConfig = (pkgs.formats.toml { }).generate "iamb/config.toml" {
    default_profile = "user";
    profiles.user.user_id = "@marv:matrix.xsfx.dev";
    layout.style = "restore";
    settings = {
      username_display = "displayname";
      image_preview = {
        # "halfblocks" (ratatui-image's fallback): no graphics protocol at all,
        # just '▀' cells with fg/bg colors -- 2 image pixels per text cell, so
        # blocky, but it renders inside zellij, which is the point.
        #   "kitty" would be crisp but only outside zellij: ratatui-image only
        #   emits the unicode-placeholder flavour (a=T,U=1), and zellij 0.45.1
        #   answers that with ENOTSUPPORTED (kitty_graphics/parser.rs) -- it
        #   only handles direct placements (c=/r=/C=1), which is what pi emits.
        #   Worth switching back if upstream PR #5531 (U=1 support) merges.
        #   "sixel" renders nowhere here at all -- ghostty has no sixel.
        # Default size is 66x10 cells (=66x20 px); settings.image_preview.size
        # trades message-list space for detail if that's too coarse.
        protocol.type = "halfblocks";
      };
      sort.rooms = [
        "unread"
        "favorite"
        "recent"
        "name"
      ];
      notifications = {
        enabled = true;
        via = "bell";
      };
    };
  };

  # Element Desktop merges a config.json from Electron's userData dir over the
  # webapp's baked-in one (apps/desktop/src/config.ts), so this is where both the
  # homeserver default and the theme go -- no element-web rebuild needed. The
  # theme itself is shared with the web client's config; see
  # lib/element-theme.nix.
  elementConfig = {
    brand = "Element";
    default_server_config = {
      "m.homeserver" = {
        base_url = "https://matrix.xsfx.dev";
        server_name = "matrix.xsfx.dev";
      };
      "m.identity_server".base_url = "";
    };
    default_theme = "custom-Dracula";
    setting_defaults.custom_themes = [ (import ../../lib/element-theme.nix) ];
  };
in
lib.mkIf cfg.matrix {

  home.packages = [
    pkgs.iamb
    # Element Desktop from cache. The webapp is nixpkgs' stock element-web, not
    # the one dipper serves, so login defaults to app.element.io and the domain
    # is typed once; overriding element-web here would mean rebuilding all of
    # element-web + Electron locally on every nixpkgs bump. Wayland comes from
    # NIXOS_OZONE_WL in hosts/coltrane/configuration.nix, at runtime.
    pkgs.element-desktop
  ];

  xdg.configFile."iamb/config.toml".source = iambConfig;

  home.file.".config/Element/config.json".text = builtins.toJSON elementConfig;
}
