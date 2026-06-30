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
    grafana = {
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
  };
}
