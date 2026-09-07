{
  nixosConfig,
  config,
  lib,
  ...
}:
let
  cfg = nixosConfig.features;
  home = config.home.homeDirectory;
in
lib.mkIf cfg.kodi {
  sops.secrets = {
    "kodi-advancedsettings.xml" = {
      path = "${home}/.kodi/userdata/advancedsettings.xml";
    };

    "kodi-passwords.xml" = {
      path = "${home}/.kodi/userdata/passwords.xml";
    };

    "kodi-sources.xml" = {
      path = "${home}/.kodi/userdata/sources.xml";
    };
  };

  programs.kodi = {
    enable = true;
  };
}
