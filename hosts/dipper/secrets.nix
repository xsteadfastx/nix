_: {
  sops.defaultSopsFile = ./secrets.yaml;
  # Telegram needs API_ID/API_HASH (account login).
  sops.secrets."mautrix-telegram-env" = { };
  # Restic backup repo URL + password (mirrors hosts/abed/backup.nix).
  sops.secrets."restic_repo_file" = { };
  sops.secrets."restic_pass_file" = { };
  # WhatsApp & Signal auto-generate their appservice tokens and pair via QR.
  # sops.secrets."mautrix-whatsapp-env" = { };
}
