_: {
  sops.defaultSopsFile = ./secrets.yaml;
  # Telegram needs API_ID/API_HASH (account login).
  sops.secrets."mautrix-telegram-env" = { };
  # Restic backup repo URL + password (mirrors hosts/abed/backup.nix).
  sops.secrets."restic_repo_file" = { };
  sops.secrets."restic_pass_file" = { };
  # LiveKit API credentials, `matrix-rtc: <secret>`. One file for both daemons --
  # LiveKit's --key-file and lk-jwt's LIVEKIT_KEY_FILE use the same
  # `<key>: <secret>` format, and the key name is what ties them together.
  sops.secrets."livekit-key" = { };
  # WhatsApp & Signal auto-generate their appservice tokens and pair via QR.
  # sops.secrets."mautrix-whatsapp-env" = { };
}
