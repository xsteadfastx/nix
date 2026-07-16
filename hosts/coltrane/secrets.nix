_: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets."paperless-admin-password" = {
    owner = "paperless";
  };
  sops.secrets."paperless-api-token" = {
    owner = "paperless";
  };
  sops.secrets."paperless-gpt-env" = { };

  # grafana-viz-mon MCP (monitoring Grafana instance)
  sops.secrets."mcp-grafana-token" = {
    owner = "marv";
  };

  sops.secrets."mcp-grafana-url" = {
    owner = "marv";
  };

  # grafana-viz MCP (second Grafana instance)
  sops.secrets."mcp-grafana-viz-token" = {
    owner = "marv";
  };

  sops.secrets."mcp-grafana-viz-url" = {
    owner = "marv";
  };

  # Permanent YouTrack API token (scope: YouTrack) for the remote MCP server.
  sops.secrets."mcp-youtrack-token" = {
    owner = "marv";
  };

  # YouTrack MCP endpoint URL (<instance>/mcp).
  sops.secrets."mcp-youtrack-url" = {
    owner = "marv";
  };

  # Hemingway MCP proxy: deployed Hemingway API URL + Caddy basic-auth creds.
  # `hemingway mcp` reads these as HEMINGWAY_SERVICES_API / HEMINGWAY_MCP_USERNAME /
  # HEMINGWAY_MCP_PASSWORD via the hemingway-mcp wrapper (hosts/coltrane/
  # coding-agent.nix).
  sops.secrets."mcp-hemingway-url" = {
    owner = "marv";
  };
  sops.secrets."mcp-hemingway-username" = {
    owner = "marv";
  };
  sops.secrets."mcp-hemingway-password" = {
    owner = "marv";
  };

  sops.secrets."gh-token" = {
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
