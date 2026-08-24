{
  nixosConfig,
  lib,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.kodi {
  sops.secrets = {
    "kodi-advancedsettings.xml" = {
      path = "$HOME/.kodi/userdata/advancedsettings.xml";
    };

    "kodi-passwords.xml" = {
      path = "$HOME/.kodi/userdata/passwords.xml";
    };

    "kodi-sources.xml" = {
      path = "$HOME/.kodi/userdata/sources.xml";
    };
  };

  programs.kodi = {
    enable = true;
  };
}
