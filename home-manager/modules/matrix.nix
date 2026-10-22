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

  # nheko draws its whole UI in Qt Quick, which can't use Kvantum: nixpkgs' wrapper
  # unsets QT_STYLE_OVERRIDE, else the window stays blank (nixpkgs#333009, still
  # true with 0.12.1). So nheko alone takes its palette from qt6ct -- the palette,
  # qt6ct.conf and the theme=system pin live with the rest of the theming in
  # gtk/default.nix. qt6ct comes from the same pkgs as nheko, so both link the
  # same qtbase.
  nheko = pkgs.symlinkJoin {
    name = "nheko-qt6ct-${pkgs.nheko.version}";
    paths = [ pkgs.nheko ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/nheko \
        --set QT_QPA_PLATFORMTHEME qt6ct \
        --prefix QT_PLUGIN_PATH : ${pkgs.qt6Packages.qt6ct}/lib/qt-6/plugins
    '';
  };
in
lib.mkIf cfg.matrix {

  home.packages = [
    pkgs.iamb
    nheko
  ];

  xdg.configFile."iamb/config.toml".source = iambConfig;
}
