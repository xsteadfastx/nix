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
    settings.username_display = "displayname";
    settings.image_preview = {
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
    settings.sort.rooms = [
      "unread"
      "favorite"
      "recent"
      "name"
    ];
    settings.notifications = {
      enabled = true;
      via = "bell";
    };
  };
in
lib.mkIf cfg.matrix {

  home.packages = [
    pkgs.iamb
  ];

  xdg.configFile."iamb/config.toml".source = iambConfig;
}
