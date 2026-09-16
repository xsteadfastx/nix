_: {
  sops.defaultSopsFile = ./secrets.yaml;
  # No required secrets: WhatsApp & Signal auto-generate their appservice tokens
  # and pair interactively via QR. (Telegram's API_ID/API_HASH is on hold until
  # we can get the credentials from my.telegram.org.)
  # sops.secrets."mautrix-telegram-env" = { };
}
