{
  inputs,
  ...
}:
let
  # coding-agent packages: single-sourced from the coding-agent repo's own
  # overlay. That overlay builds the Python MCP servers (mcp-atlassian,
  # postgres-mcp, redis-mcp, netbox-mcp, activity-mcp) from source against
  # whatever channel it is applied to, so WE must choose the channel.
  #
  # We choose theirs: the nixpkgs pinned in the coding-agent repo's own
  # flake.lock, i.e. the exact revision upstream builds and tests its packages
  # against. Applying the overlay to our `nixpkgs-unstable` instead couples
  # their packages to our channel's churn — it broke on 2026-10-23 when our
  # unstable moved python `mcp` to 2.x (`McpError` → `MCPError`), which fastmcp
  # 3.4.7 (the only version in nixpkgs) cannot import, so mcp-atlassian, and
  # with it every host importing this module, stopped evaluating.
  #
  # Same reasoning as the repo's `nixpkgs-playwright` pin: upstream keeps the
  # recipe and its dependency set together, so we don't move half of it.
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

  # Built once per `final`, not once per attribute.
  mkCodingAgentPkgs =
    system:
    import inputs.coding-agent.inputs.nixpkgs {
      inherit system;
      # claude-code is unfree.
      config.allowUnfree = true;
      overlays = [ codingAgentOverlay ];
    };
in
{
  inherit codingAgentOverlay codingAgentPkgs;

  overlay =
    final: _prev:
    let
      pkgs = mkCodingAgentPkgs final.stdenv.hostPlatform.system;
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = pkgs.${name};
      }) codingAgentPkgs
    );
}
