_: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets."paperless-admin-password" = { };
  sops.secrets."paperless-gpt-env" = { };
  sops.secrets."local-ca-key" = {
    owner = "caddy";
    mode = "0400";
  };
}
