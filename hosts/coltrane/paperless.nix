{ config, ... }:
{
  users.users.marv.extraGroups = [ "paperless" ];
  systemd.tmpfiles.rules = [
    "d /var/lib/paperless/consume 0775 paperless paperless - -"
  ];
  services.paperless = {
    enable = true;
    port = 28981;
    address = "127.0.0.1";
    settings = {
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_TIME_ZONE = "Europe/Berlin";
      PAPERLESS_URL = "http://127.0.0.1:28981";
    };
    passwordFile = config.sops.secrets."paperless-admin-password".path;
    # environmentFile = config.sops.secrets."paperless-env".path;
  };
}
