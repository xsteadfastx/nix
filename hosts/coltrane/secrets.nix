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

  # Hemingway MCP: deployed Hemingway API base URL + Caddy basic-auth creds.
  # The bespoke hemingway-mcp wrapper (hosts/coltrane/coding-agent.nix) reads
  # these as HEMINGWAY_SERVICES_API / HEMINGWAY_MCP_USERNAME / HEMINGWAY_MCP_PASSWORD
  # (via the module's *_FILE secret wrapper) and bridges the deployed API's
  # in-process /mcp endpoint (StreamableHTTP) to stdio with mcp-proxy, sending
  # `Authorization: Basic <base64(user:pass)>`.
  sops.secrets."mcp-hemingway-url" = {
    owner = "marv";
  };
  sops.secrets."mcp-hemingway-username" = {
    owner = "marv";
  };
  sops.secrets."mcp-hemingway-password" = {
    owner = "marv";
  };

  # Confluence MCP (sooperset/mcp-atlassian): self-hosted Data Center instance
  # at https://confluence.service.wobcom.de. Data Center auth uses a personal
  # access token (CONFLUENCE_PERSONAL_TOKEN), not email+API-token. Generate it
  # in Confluence (Profile → Personal Access Tokens) and store in sops.
  sops.secrets."mcp-confluence-url" = {
    owner = "marv";
  };
  sops.secrets."mcp-confluence-token" = {
    owner = "marv";
  };

  sops.secrets."gh-token" = {
    owner = "marv";
  };

  # NetBox MCP (netboxlabs/netbox-mcp-server): read-only REST API access.
  # URL is a secret here too, so both are injected via the *_FILE convention.
  sops.secrets."mcp-netbox-token" = {
    owner = "marv";
  };
  sops.secrets."mcp-netbox-url" = {
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
