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
      # Not "kitty": zellij 0.45 rejects kitty's Unicode-placeholder (U=1)
      # placements with ENOTSUPPORTED, and ratatui-image (iamb's renderer) draws
      # previews exactly that way — so every preview silently rendered as nothing
      # inside zellij, while pi kept working because it places images directly
      # (c=/r= cells instead of U=1). Ghostty has no sixel, but zellij parses
      # sixel itself and re-emits it, so sixel is the path that renders here.
      # Switch back to "kitty" once zellij ships PR #5531 (U=1 support, after
      # 0.45.1) or when running iamb outside zellij. "halfblocks" renders
      # anywhere, as blocky pixel art, if sixel turns out to misbehave.
      protocol.type = "sixel";
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
