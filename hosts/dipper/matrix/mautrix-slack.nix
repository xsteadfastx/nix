import ./mautrix-bridge.nix {
  name = "mautrix-slack";
  bridge = "slack";
  # appservice listener; 8080 is the telegram bridge's
  port = 29338;
}
