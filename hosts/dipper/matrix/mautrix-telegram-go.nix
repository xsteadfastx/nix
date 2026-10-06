import ./mautrix-bridge.nix {
  name = "mautrix-telegram";
  # the option is -go because nixpkgs already has the legacy Python bridge there
  optionName = "mautrix-telegram-go";
  bridge = "telegram";
  port = 8080;
  # env_config_prefix is MAUTRIX_TELEGRAM_ (derived), but what it actually
  # carries is the nested network settings -- double `__` = a `.` in the path.
  envHint = ''
    (`MAUTRIX_TELEGRAM_NETWORK__API_ID`, `MAUTRIX_TELEGRAM_NETWORK__API_HASH`, ...).
    Note: `__` encodes a `.` in the config path (single `_` does not).'';
}
