{
  lib,
  python3Packages,
  fetchFromGitHub,
  redis-entraid,
}:

# redis/mcp-redis — the official Redis MCP server. Not in nixpkgs, so built from
# source. Build backend is uv_build (nixpkgs' `uv-build`), with the whole `src`
# dir as the top-level module (module-name = "src"), so the console script is
# `src.main:cli`. NOTE: this server has NO read-only mode — it exposes full
# read/write tools (set/del/flushdb). Wire it to a Redis ACL user if you want
# to restrict writes (see hosts/coltrane/coding-agent.nix).
python3Packages.buildPythonApplication rec {
  pname = "redis-mcp-server";
  version = "0.5.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "redis";
    repo = "mcp-redis";
    rev = version;
    hash = "sha256-M8t3ivUeIAm2YDZmIqoSQyUuMtj6IgaTp5YtgA7UYBI=";
  };

  # Read-only hardening: redis-mcp-server has no native read-only mode, so this
  # patch drops every write tool (set/del/expire/rename/… ) after registration.
  patches = [ ./redis-mcp-readonly.patch ];

  build-system = [ python3Packages.uv-build ];

  dependencies = with python3Packages; [
    mcp
    redis
    python-dotenv
    numpy
    click
    aiohttp
    redis-entraid
  ];

  pythonImportsCheck = [ "src" ];

  doCheck = false;

  meta = {
    description = "Redis MCP Server — Model Context Protocol server for Redis";
    homepage = "https://github.com/redis/mcp-redis";
    license = lib.licenses.mit;
    mainProgram = "redis-mcp-server";
  };
}
