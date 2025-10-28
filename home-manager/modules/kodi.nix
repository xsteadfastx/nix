{
  nixosConfig,
  lib,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.kodi {
  age.secrets = {
    "kodi-advancedsettings.xml" = {
      file = ../../secrets/kodi-advancedsettings.xml;
      path = "$HOME/.kodi/userdata/advancedsettings.xml";
    };

    "kodi-passwords.xml" = {
      file = ../../secrets/kodi-passwords.xml;
      path = "$HOME/.kodi/userdata/passwords.xml";
    };

    "kodi-sources.xml" = {
      file = ../../secrets/kodi-sources.xml;
      path = "$HOME/.kodi/userdata/sources.xml";
    };
  };

  programs.kodi = {
    enable = true;
  };
}
