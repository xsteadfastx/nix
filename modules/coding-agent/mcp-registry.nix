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
    # mcp-proxy bridges a remote StreamableHTTP MCP server to stdio.
    youtrack = {
      bin = pkgs.mcp-proxy;
      command = "mcp-proxy";
    };
  };
}
