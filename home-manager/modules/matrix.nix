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
