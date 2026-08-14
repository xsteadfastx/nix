{ pkgs, ... }:
{
  # The MCP Registry defines the mapping between a logical name
  # and the actual Nix package/binary.
  mcpRegistry = {
    nixos = {
      bin = pkgs.mcp-nixos;
      command = "mcp-nixos";
    };
    git = {
      bin = pkgs.mcp-server-git;
      command = "mcp-server-git";
    };
    github = {
      bin = pkgs.github-mcp-server;
      command = "github-mcp-server";
    };
    # Two Grafana instances, same upstream binary, distinct credentials
    # (see hosts/coltrane/coding-agent.nix). Each instance's URL + token live
    # encrypted in sops. Keys are short because FQDNs can't be MCP server keys
    # (dots are invalid in tool names and the prefixed names would exceed the
    # 64-char tool-name limit).
    grafana-viz-mon = {
      bin = pkgs.mcp-grafana;
      command = "mcp-grafana";
    };
    grafana-viz = {
      bin = pkgs.mcp-grafana;
      command = "mcp-grafana";
    };
    context7 = {
      bin = pkgs.context7-mcp;
      command = "context7-mcp";
    };
    confluence = {
      bin = pkgs.mcp-atlassian;
      command = "mcp-atlassian";
    };
    "sequential-thinking" = {
      bin = pkgs.mcp-server-sequential-thinking;
      command = "mcp-server-sequential-thinking";
    };
    playwright = {
      bin = pkgs.playwright-mcp;
      command = "playwright-mcp";
    };
    memory = {
      bin = pkgs.mcp-server-memory;
      command = "mcp-server-memory";
    };
    # Official Redis MCP (redis/mcp-redis). Patched read-only (write tools
    # removed — see pkgs/redis-mcp-readonly.patch).
    redis = {
      bin = pkgs.redis-mcp-server;
      command = "redis-mcp-server";
    };
    # mcp-proxy bridges a remote StreamableHTTP MCP server to stdio.
    youtrack = {
      bin = pkgs.mcp-proxy;
      command = "mcp-proxy";
    };
    # Hemingway hosts its MCP server in-process at /mcp on the deployed API
    # (v0.89.17+, StreamableHTTP, behind the same Caddy basic_auth as the API).
    # mcp-proxy bridges that remote endpoint to stdio. Caddy basic_auth needs an
    # `Authorization: Basic <base64(user:pass)>` header, which mcp-proxy has no
    # native option for (only `-H KEY VALUE` or the `API_ACCESS_TOKEN` Bearer
    # shortcut), so the host provides a bespoke writeShellApplication wrapper
    # (hemingwayMcp) that builds the header from the HEMINGWAY_* sops secrets
    # and execs mcp-proxy; the host's mcpServers entry overrides `bin`/`command`
    # with it. Host config (API URL + basic-auth creds) is injected via HEMINGWAY_*
    # `*_FILE` env vars in the host's mcpServers entry.
    hemingway = {
      bin = pkgs.mcp-proxy;
      command = "mcp-proxy";
    };
  };
}
