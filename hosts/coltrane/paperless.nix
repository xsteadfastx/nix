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

  # Zettelrobbe: an LLM names title, tags, correspondent and type for new
  # documents — the one thing paperless's own classifier cannot do, because it
  # only picks from names it has already seen. Packaged natively (it is plain
  # Node), so nothing sits in a container: server.js resolves its assets from
  # __dirname and keeps its state in $PWD/data, hence WorkingDirectory below.
  #
  # Configuration lives HERE, not in the setup wizard. config.js:93-104 treats any
  # key present in the process environment at startup as "protected": it is never
  # overridden by data/runtime-overrides.json (what the wizard saves) and never
  # written back to it. The wizard is needed once, for the admin account, which
  # lives in documents.db as a bcrypt hash and has no environment variable.
  users.users.zettelrobbe = {
    isSystemUser = true;
    group = "zettelrobbe";
  };
  users.groups.zettelrobbe = { };

  systemd.services.zettelrobbe = {
    description = "Zettelrobbe — LLM tagging for paperless-ngx";
    wantedBy = [ "multi-user.target" ];
    after = [ "paperless-web.service" ];
    # ollama runs as a *user* service, so it cannot be ordered against here; it is
    # only needed when a request is made, and a missing answer just fails that run.
    serviceConfig = {
      ExecStart = "${pkgs.zettelrobbe}/bin/zettelrobbe";
      # server.js: dataDir = path.join(process.cwd(), 'data')
      WorkingDirectory = "/var/lib/zettelrobbe";
      StateDirectory = "zettelrobbe";
      User = "zettelrobbe";
      Group = "zettelrobbe";
      Restart = "on-failure";
      RestartSec = 5;
    };
    environment = {
      # Gotenberg (services.gotenberg.port) already owns 127.0.0.1:3000, upstream's
      # default, so ask for a port next to paperless's 28981 instead.
      PAPERLESS_AI_PORT = "28982";
      PAPERLESS_API_URL = "http://127.0.0.1:28981";
      PAPERLESS_PUBLIC_URL = "https://paperless.local";
      # The setup wizard resolves the hostname and refuses any URL that lands on
      # loopback unless this is set (services/serviceUtils.js:630-646 — it checks
      # the *resolved* addresses, so paperless.local counts as 127.0.0.1 too).
      PAPERLESS_AI_SETUP_ALLOW_LOCALHOST = "true";

      AI_PROVIDER = "ollama";
      OLLAMA_API_URL = "http://127.0.0.1:11434";
      # `:cloud` — this model is not on disk, the local ollama proxies it to
      # ollama.com, so every analysed document leaves the machine.
      OLLAMA_MODEL = "deepseek-v4.1-flash:cloud";
      # Cost brake per document, not a context limit: a 17-page scan is ~40k
      # characters and naming a sender never needs all of it.
      CONTENT_MAX_LENGTH = "15000";

      # Scope. `yes` + TAGS restricted it to tagged documents, which meant every
      # new mail document had to be tagged by hand before the LLM saw it. `no`
      # lets every NEW document through; the ones already analysed are protected
      # by processed_documents in documents.db, not by this switch.
      PROCESS_PREDEFINED_DOCUMENTS = "no";

      # What it is allowed to write. No custom fields: `Betrag` belongs to
      # paperless-enrich, which derives it from a regex, not to a guess.
      # Document types exist (19 of them) but were unused; restricting the choice
      # to them keeps the vocabulary from growing.
      ACTIVATE_TITLE = "yes";
      ACTIVATE_TAGGING = "yes";
      ACTIVATE_CORRESPONDENTS = "yes";
      ACTIVATE_DOCUMENT_TYPE = "yes";
      RESTRICT_TO_EXISTING_DOCUMENT_TYPES = "yes";
      ACTIVATE_CUSTOM_FIELDS = "no";
      ADD_AI_PROCESSED_TAG = "yes";
      AI_PROCESSED_TAG_NAME = "ai-processed";
      IGNORE_TAGS = "ai-processed";
      # Tags must stay inside the vocabulary that exists — the unrestricted run
      # invented ~98 of them. The correspondent deliberately may be new: naming a
      # sender the archive has never seen ("Homann & Freitag GbR") is the whole
      # reason this service is here.
      RESTRICT_TO_EXISTING_TAGS = "yes";
      RESTRICT_TO_EXISTING_CORRESPONDENTS = "no";
      SYSTEM_PROMPT = ''
        Du analysierst Dokumente eines privaten Archivs. Bestimme den Absender
        (correspondent), einen kurzen Titel und auf Wunsch die Dokumentart.
        Antworte in der Sprache des Dokuments.
        Nimm höchstens vier Tags, und nur aus dieser Liste: %RESTRICTED_TAGS%
        Passt keiner, lass das Feld weg, statt einen neuen Tag zu erfinden.
        Der correspondent ist der Absender, niemals der Empfänger.
      '';

      SCAN_INTERVAL = "*/30 * * * *";
      DISABLE_AUTOMATIC_PROCESSING = "no";

      # OCR rescue queue for scans paperless itself read badly. Provider stays the
      # local ollama, the model is one of the `:cloud` ones it proxies to
      # ollama.com — so no Mistral account or API key is needed, but the page
      # images do leave the machine. A local vision model (qwen3.5:latest) is the
      # offline alternative, slower and worse on german scans.
      MISTRAL_OCR_ENABLED = "yes";
      OCR_PROVIDER = "ollama";
      MISTRAL_OCR_MODEL = "mistral-large-4:cloud"; # vision, 1M ctx, via ollama.com
      # Empty on purpose: the wizard stored http://localhost:11434 here when the
      # provider was still ollama, and a set OCR_API_URL is used as the endpoint
      # override. An env key wins over that stored value.
      OCR_API_URL = "";
      # Left off deliberately: with it, the queue burns API credit on its own.
      # Documents are processed from /ocr on demand instead.
      OCR_AUTO_PROCESS_ENABLED = "no";

      # Behind caddy's internal TLS, see hosts/coltrane/caddy/default.nix.
      COOKIE_SECURE_MODE = "auto";
      TRUST_PROXY = "1";
      ANONYMIZED_TELEMETRY = "no";
      UPDATE_CHECK_ENABLED = "no"; # updates are the package version bump
    };
  };
}
