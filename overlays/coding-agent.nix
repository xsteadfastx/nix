{
  inputs,
  ...
}:
let
  # coding-agent packages: single-sourced from the coding-agent repo's own
  # overlay (see modules/base), so we don't duplicate their definitions here.
  # The repo overlay builds the Python MCP servers (mcp-atlassian, redis-mcp)
  # from source against whatever channel it's applied to — those need recent
  # deps (cattrs>=26.1, lxml>=6.1) that only exist on nixos-unstable, so we
  # apply it to this repo's nested `unstable` instance (see unstable.nix), then
  # surface the names at the top level where the coding-agent module reads
  # them as plain `pkgs.*`.
  codingAgentOverlay = inputs.coding-agent.overlays.default;

  # The package names the coding-agent module consumes as top-level pkgs.*.
  codingAgentPkgs = [
    "pi-coding-agent"
    "claude-code"
    "postgres-mcp"
    "mcp-atlassian"
    "redis-mcp-server"
    "agent-browser"
    "mcp-nixos"
    "mcp-server-git"
    "mcp-grafana"
    "github-mcp-server"
    "context7-mcp"
    "mcp-server-sequential-thinking"
    "mcp-server-memory"
    "netbox-mcp-server"
    "activity-mcp"
    "playwright-mcp"
    "mcp-proxy"
    "github-cli"
    "ripgrep"
  ];
in
{
  inherit codingAgentOverlay codingAgentPkgs;

  # Surface the unstable-instance coding-agent packages as top-level `pkgs.*`
  # (the coding-agent module reads them there). Must be composed AFTER the
  # `unstable` overlay, since it reads `final.unstable`.
  overlay =
    final: _prev:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = final.unstable.${name};
      }) codingAgentPkgs
    );
}
