{
  lib,
  python3Packages,
  fetchFromGitHub,
  markdown-to-confluence,
}:

# sooperset/mcp-atlassian — the standard MCP server for Atlassian (Confluence
# + Jira), Cloud and Server/Data Center. Not in nixpkgs, so built from source
# (the postgres-mcp pattern). Every runtime dep is in nixpkgs; three need a
# version-bound relaxation because nixpkgs ships newer/older than the pins:
#   * fastmcp: nixpkgs 3.3.1 vs pin >=3.4.4  (lower bound)
#   * fakeredis: nixpkgs 2.36.2 vs pin <2.35.0 (upper bound)
#   * cryptography: nixpkgs 50.0.0 vs pin <47  (upper bound)
# markdown-to-confluence (hunyadi/md2conf) is not in nixpkgs either — packaged
# separately in pkgs/markdown-to-confluence.nix and passed in via the overlay.
# Driven read-only via `--read-only` (disables all write tools).
python3Packages.buildPythonApplication rec {
  pname = "mcp-atlassian";
  version = "0.23.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "sooperset";
    repo = "mcp-atlassian";
    tag = "v${version}";
    hash = "sha256-aTiPYMhZwWCjS/S9pZgdb4oFbXyNO7Q/aMUt0bKfSjM=";
  };

  build-system = [
    python3Packages.hatchling
    python3Packages.uv-dynamic-versioning
  ];

  pythonRelaxDeps = [
    "fastmcp"
    "fakeredis"
    "cryptography"
  ];

  dependencies = with python3Packages; [
    anyio
    atlassian-python-api
    requests
    beautifulsoup4
    httpx
    mcp
    fastmcp
    fakeredis
    python-dotenv
    markdownify
    markdown
    markdown-to-confluence
    pydantic
    trio
    click
    uvicorn
    starlette
    urllib3
    thefuzz
    python-dateutil
    types-python-dateutil
    keyring
    cachetools
    unidecode
    cryptography
    truststore
  ];

  pythonImportsCheck = [ "mcp_atlassian" ];

  # The wheel's metadata lists `types-cachetools` (a mypy type-stub, never
  # imported at runtime) as a dependency; it's not in nixpkgs and isn't needed
  # to run, so skip the runtime-deps check rather than package a stub.
  dontCheckRuntimeDeps = true;

  # dev-only deps (pytest) pull heavy trees and need live Atlassian instances.
  doCheck = false;

  meta = {
    description = "MCP server for Atlassian products (Confluence and Jira), Cloud and Data Center";
    homepage = "https://github.com/sooperset/mcp-atlassian";
    license = lib.licenses.mit;
    mainProgram = "mcp-atlassian";
  };
}
