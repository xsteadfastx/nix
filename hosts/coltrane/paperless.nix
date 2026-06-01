{
  config,
  lib,
  pkgs,
  ...
}:
let

  correspondentPrompt = pkgs.writeText "correspondent_prompt.tmpl" ''
    I will provide you with the content of a document. Your task is to suggest a correspondent that is most relevant to the document.

    Correspondents are the senders of documents that reach you. In the other direction, correspondents are the recipients of documents that you send.

    You MUST only select a correspondent from the <example_correspondents> list below.
    Do NOT invent or suggest a new correspondent that is not in the list.
    If no correspondent from the list matches, respond with "Unknown".

    Respond only with a correspondent, without any additional information!

    Try to avoid any legal or financial suffixes like "GmbH" or "AG" in the correspondent name.
    For example use "Microsoft" instead of "Microsoft Ireland Operations Limited" or "Amazon" instead of "Amazon EU S.a.r.l.".

    The data will be provided using an XML-like format for clarity:

    Important constraints:
    - Only return a name from <example_correspondents>.
    - Never return a name that appears in <blacklisted_correspondents>.
    - If unsure, respond with "Unknown".

    <example_correspondents>
    {{.AvailableCorrespondents | join ", "}}
    </example_correspondents>

    <blacklisted_correspondents>
    {{.BlackList | join ", "}}
    </blacklisted_correspondents>

    <title>
    {{.Title}}
    </title>

    <content>
    {{.Content}}
    </content>

    The content is likely in {{.Language}}.
  '';

  titlePrompt = pkgs.writeText "title_prompt.tmpl" ''
    I will provide you with the content of a document that has been partially read by OCR (so it may contain errors).
    Your task is to find a suitable document title that I can use as the title in the paperless-ngx program.
    If the original title is already adding value and not just a technical filename you can use it as extra information to enhance your suggestion.
    Respond only with the title, without any additional information. The content is likely in {{.Language}}.
    Always respond with the title in German (Deutsch), regardless of the document's original language.

    The data will be provided using an XML-like format for clarity:

    <original_title>{{.Title}}</original_title>
    <content>
    {{.Content}}
    </content>
  '';

  tagPrompt = pkgs.writeText "tag_prompt.tmpl" ''
    I will provide you with the content and the title of a document.
    Your task is to select appropriate tags for the document from the list of available tags I will provide.
    Only select tags from the provided list. Respond only with the selected tags as a comma-separated list, without any additional information.
    The content is likely in {{.Language}}.

    The data will be provided using an XML-like format for clarity:

    <available_tags>
    {{.AvailableTags | join ", "}}
    </available_tags>

    <title>
    {{.Title}}
    </title>

    <content>
    {{.Content}}
    </content>

    Please concisely select the {{.Language}} tags from the list above that best describe the document.
    Be very selective and only choose the most relevant tags since too many tags will make the document less discoverable.
    Only select a tag if it clearly and directly describes the document's category or type.
    Do NOT select a tag just because the word appears in the document — for example, do not tag a document as "tickets" because it contains a support ticket reference number or ID in an invoice.
  '';

  prompts = pkgs.runCommand "paperless-gpt-prompts" { } ''
    cp -r --no-preserve=mode ${pkgs.paperless-gpt}/share/paperless-gpt/default-prompts $out
    install -m 644 ${correspondentPrompt} $out/correspondent_prompt.tmpl
    install -m 644 ${titlePrompt} $out/title_prompt.tmpl
    install -m 644 ${tagPrompt} $out/tag_prompt.tmpl
  '';

  fetchTessdataBest =
    { lang, hash }:
    pkgs.fetchurl {
      url = "https://github.com/tesseract-ocr/tessdata_best/raw/4.1.0/${lang}.traineddata";
      inherit hash;
    };

  postConsumeScript = pkgs.writeShellScript "paperless-post-consume" ''
    # only process Amazon documents (correspondent id 1)
    if [ "$DOCUMENT_CORRESPONDENT_ID" != "1" ]; then
      exit 0
    fi

    password=$(cat ${config.sops.secrets."paperless-admin-password".path})

    content=$(${pkgs.curl}/bin/curl -sf \
      "http://127.0.0.1:28981/api/documents/$DOCUMENT_ID/" \
      -u "admin:$password" \
      | ${pkgs.jq}/bin/jq -r '.content')

    amount=$(printf '%s' "$content" \
      | ${pkgs.gnugrep}/bin/grep -oP 'Summe\s+\K[\d.]+(?=\s+EUR)' \
      | head -1)

    if [ -z "$amount" ]; then
      exit 0
    fi

    ${pkgs.curl}/bin/curl -sf -X PATCH \
      "http://127.0.0.1:28981/api/documents/$DOCUMENT_ID/" \
      -u "admin:$password" \
      -H "Content-Type: application/json" \
      -d "{\"custom_fields\":[{\"field\":1,\"value\":\"EUR$amount\"}]}"
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
  systemd.tmpfiles.rules = [
    "d /var/lib/paperless/consume 0775 paperless paperless - -"
  ];

  services.gotenberg.chromium.disableJavascript = lib.mkForce false;
  services.gotenberg.extraArgs = lib.mkForce [ "--chromium-allow-list=.*" ];

  services.paperless = {
    enable = true;
    configureTika = true;
    package = pkgs.paperless-ngx.override { tesseract5 = tesseractBest; };
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

  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    package = pkgs.ollama-vulkan;
  };

  systemd.services.paperless-gpt = {
    description = "paperless-gpt LLM auto-tagger";
    after = [
      "network.target"
      "paperless-scheduler.service"
      "ollama.service"
    ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      PAPERLESS_BASE_URL = "http://127.0.0.1:28981";
      LLM_PROVIDER = "ollama";
      LLM_MODEL = "qwen2.5:7b";
      VISION_LLM_PROVIDER = "ollama";
      VISION_LLM_MODEL = "minicpm-v:8b";
      OCR_PROVIDER = "llm";
    };
    serviceConfig = {
      ExecStartPre = pkgs.writeShellScript "paperless-gpt-prompts" ''
        chmod -R u+w default_prompts 2>/dev/null || true
        rm -rf default_prompts
        cp -r --no-preserve=mode ${prompts} default_prompts
      '';
      ExecStart = "${pkgs.paperless-gpt}/bin/paperless-gpt";
      EnvironmentFile = config.sops.secrets."paperless-gpt-env".path;
      DynamicUser = true;
      StateDirectory = "paperless-gpt";
      WorkingDirectory = "/var/lib/paperless-gpt";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
