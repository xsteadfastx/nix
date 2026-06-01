_: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets."paperless-admin-password" = {
    owner = "paperless";
  };
  sops.secrets."paperless-gpt-env" = { };
  sops.secrets."local-ca-key" = {
    owner = "caddy";
    mode = "0400";
  };
}
