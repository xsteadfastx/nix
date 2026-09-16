_: {
  sops.defaultSopsFile = ./secrets.yaml;
  # Telegram needs API_ID/API_HASH (account login).
  sops.secrets."mautrix-telegram-env" = { };
  # WhatsApp & Signal auto-generate their appservice tokens and pair via QR.
  # sops.secrets."mautrix-whatsapp-env" = { };
}
