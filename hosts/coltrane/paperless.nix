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

  extractAmount = pkgs.writeShellScript "paperless-extract-amount" ''
    correspondent_id=$1
    content=$2

    case "$correspondent_id" in
      1)
        # Amazon: "Summe 109.99 EUR"
        printf '%s' "$content" \
          | ${pkgs.gnugrep}/bin/grep -oP 'Summe\s+\K[\d.]+(?=\s+EUR)' \
          | head -1
        ;;
      14)
        # PayPal: "Gesamtbetrag 12,99 €" or "Gesamtbetrag dieser Transaktion: 26,94 €"
        printf '%s' "$content" \
          | ${pkgs.gnugrep}/bin/grep -oP 'Gesamtbetrag(?:\s+dieser\s+Transaktion)?:?\s+\K[\d,]+(?=\s*€)' \
          | head -1 \
          | ${pkgs.gnused}/bin/sed 's/,/./'
        ;;
    esac
  '';

  betragBackfillScript = pkgs.writeShellScript "paperless-betrag-backfill" ''
    token=$(cat ${config.sops.secrets."paperless-api-token".path})

    for correspondent_id in 1 14; do
      ids=$(${pkgs.curl}/bin/curl -sf \
        "http://127.0.0.1:28981/api/documents/?correspondent__id=$correspondent_id&page_size=100" \
        -H "Authorization: Token $token" \
        | ${pkgs.jq}/bin/jq -r '
            .results[]
            | select(
                (.custom_fields | map(select(.field == 1 and .value != null)) | length) == 0
              )
            | .id')

      if [ -z "$ids" ]; then
        echo "correspondent $correspondent_id: no documents missing Betrag"
        continue
      fi

      for id in $ids; do
        content=$(${pkgs.curl}/bin/curl -sf \
          "http://127.0.0.1:28981/api/documents/$id/" \
          -H "Authorization: Token $token" \
          | ${pkgs.jq}/bin/jq -r '.content')

        amount=$(${extractAmount} "$correspondent_id" "$content")

        if [ -z "$amount" ]; then
          echo "doc $id: no amount found, skipping"
          continue
        fi

        formatted=$(LC_NUMERIC=C printf '%.2f' "$amount")
        if ${pkgs.curl}/bin/curl -sf -X PATCH \
          "http://127.0.0.1:28981/api/documents/$id/" \
          -H "Authorization: Token $token" \
          -H "Content-Type: application/json" \
          -d "{\"custom_fields\":[{\"field\":1,\"value\":\"EUR$formatted\"}]}" > /dev/null; then
          echo "doc $id: set Betrag EUR$formatted"
        else
          echo "doc $id: PATCH failed"
          exit 1
        fi
      done
    done
  '';

  postConsumeScript = pkgs.writeShellScript "paperless-post-consume" ''
    if [ "$DOCUMENT_CORRESPONDENT_ID" != "1" ] && [ "$DOCUMENT_CORRESPONDENT_ID" != "14" ]; then
      exit 0
    fi

    token=$(cat ${config.sops.secrets."paperless-api-token".path})

    content=$(${pkgs.curl}/bin/curl -sf \
      "http://127.0.0.1:28981/api/documents/$DOCUMENT_ID/" \
      -H "Authorization: Token $token" \
      | ${pkgs.jq}/bin/jq -r '.content')

    amount=$(${extractAmount} "$DOCUMENT_CORRESPONDENT_ID" "$content")

    if [ -z "$amount" ]; then
      exit 0
    fi

    formatted=$(LC_NUMERIC=C printf '%.2f' "$amount")
    ${pkgs.curl}/bin/curl -sf -X PATCH \
      "http://127.0.0.1:28981/api/documents/$DOCUMENT_ID/" \
      -H "Authorization: Token $token" \
      -H "Content-Type: application/json" \
      -d "{\"custom_fields\":[{\"field\":1,\"value\":\"EUR$formatted\"}]}"
  '';

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
in
{
  users.users.marv.extraGroups = [ "paperless" ];
  systemd = {
    tmpfiles.rules = [
      "d /var/lib/paperless/consume 0775 paperless paperless - -"
    ];

    services = {
      paperless-betrag-backfill = {
        description = "Backfill Betrag custom field for Amazon documents";
        after = [ "paperless-web.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = betragBackfillScript;
          User = "paperless";
        };
      };
    };

    timers = {
      paperless-betrag-backfill = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "15min";
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
        PAPERLESS_POST_CONSUME_SCRIPT = "${postConsumeScript}";
      };
      passwordFile = config.sops.secrets."paperless-admin-password".path;
    };
  };
}
