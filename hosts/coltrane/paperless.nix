{
  config,
  lib,
  pkgs,
  ...
}:
let
  fetchTessdataBest =
    { lang, hash }:
    pkgs.fetchurl {
      url = "https://github.com/tesseract-ocr/tessdata_best/raw/4.1.0/${lang}.traineddata";
      inherit hash;
    };

  tesseractBest = pkgs.tesseract5.override {
    languages = pkgs.tesseract5.languages // {
      deu = fetchTessdataBest {
        lang = "deu";
        hash = "sha256-hAczHWqgIp3JJ2hcAaeTj8WmQdGpUk90g4zaxZnw0G4=";
      };
      eng = fetchTessdataBest {
        lang = "eng";
        hash = "sha256-goCu0Hgv4nJXpo6hD+fvMkyg+Nhb0v0UXRwrVgvLZro=";
      };
      osd = fetchTessdataBest {
        lang = "osd";
        hash = "sha256-nPXVdvzEdWTxEmWEHlyoOQAefm84/396rPRtFalrAP8=";
      };
    };
  };

  # The script and its extractor table must live in one directory: the script
  # resolves extractors.json next to itself. Adding a sender is an edit of
  # /var/lib/paperless/extractors.json, not of this file — see
  # docs/superpowers/specs/2026-11-23-paperless-paypal-enrichment-design.md
  enrichSrc = pkgs.runCommand "paperless-enrich-src" { } ''
    mkdir -p $out
    cp ${./paperless/paperless-enrich.py} $out/paperless-enrich.py
    cp ${./paperless/extractors.json} $out/extractors.json
  '';

  paperless-enrich = pkgs.writeShellScriptBin "paperless-enrich" ''
    export PAPERLESS_BASE_URL="http://127.0.0.1:${toString config.services.paperless.port}"
    export PAPERLESS_TOKEN_FILE="${config.sops.secrets."paperless-api-token".path}"
    exec ${pkgs.python3}/bin/python3 ${enrichSrc}/paperless-enrich.py "$@"
  '';
in
{
  users.users.marv.extraGroups = [ "paperless" ];
  systemd = {
    tmpfiles.rules = [
      "d /var/lib/paperless/consume 0775 paperless paperless - -"
    ];

    services = {
      paperless-enrich = {
        description = "Backfill paperless correspondent, title and Betrag from document text";
        after = [ "paperless-web.service" ];
        serviceConfig = {
          Type = "oneshot";
          # `after=` means started, not serving: granian binds the port about a
          # second before its worker can answer, which made the first backfill
          # after a switch die on ECONNREFUSED.
          ExecStartPre = "${paperless-enrich}/bin/paperless-enrich --wait";
          ExecStart = "${paperless-enrich}/bin/paperless-enrich --backfill";
          User = "paperless";
        };
      };
    };

    timers = {
      paperless-enrich = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "1h";
        };
      };
    };
  };

  services = {
    gotenberg.chromium.disableJavascript = lib.mkForce false;
    gotenberg.extraArgs = lib.mkForce [ "--chromium-allow-list=.*" ];

    paperless = {
      enable = true;
      configureTika = true;
      package = (pkgs.paperless-ngx.override { tesseract5 = tesseractBest; }).overrideAttrs (_: {
        doInstallCheck = false;
      });
      port = 28981;
      address = "127.0.0.1";
      settings = {
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_OCR_USER_ARGS = builtins.toJSON {
          optimize = 1;
          clean_final = true;
          deskew = true;
        };
        PAPERLESS_TIME_ZONE = "Europe/Berlin";
        PAPERLESS_URL = "https://paperless.local";
        PAPERLESS_EMAIL_TASK_CRON = "*/10 * * * *";
        PAPERLESS_DATE_ORDER = "DMY";
        PAPERLESS_POST_CONSUME_SCRIPT = "${paperless-enrich}/bin/paperless-enrich";
        # doc_pk keeps the name collision-free: a duplicate title+date would
        # otherwise make consumption fail on an existing target path.
        PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{created}_{doc_pk}";
        PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = "YES";
      };
      passwordFile = config.sops.secrets."paperless-admin-password".path;
    };
  };
}
