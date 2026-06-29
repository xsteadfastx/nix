_: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets."paperless-admin-password" = {
    owner = "paperless";
  };
  sops.secrets."paperless-api-token" = {
    owner = "paperless";
  };
  sops.secrets."paperless-gpt-env" = { };

  sops.secrets."mcp-grafana-token" = {
    owner = "marv";
  };

  sops.secrets."mcp-grafana-url" = {
    owner = "marv";
  };

  sops.secrets."local-ca-key" = {
    owner = "caddy";
    mode = "0400";
  };
  sops.secrets."local-intermediate-key" = {
    owner = "caddy";
    mode = "0400";
  };
}
