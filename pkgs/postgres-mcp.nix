{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

# crystaldba/postgres-mcp ("Postgres MCP Pro") — the most popular postgres MCP
# (~3k★, actively maintained), unlike the archived MCP-monorepo server whose
# "read-only" mode happily ran DROP SCHEMA. Not in nixpkgs, so built from
# source. Every runtime dep is already in nixpkgs at a compatible version, so
# plain buildPythonApplication resolves it — no uv2nix/lockfile machinery.
# Only wrinkle: pyproject pins pglast ==7.11 but nixpkgs ships 7.13, so relax
# that single bound. Driven read-only via `--access-mode restricted` (pglast
# SQL-parse enforcement); pair with a pg_read_all_data role on the DB side.
python3Packages.buildPythonApplication rec {
  pname = "postgres-mcp";
  version = "0.3.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "crystaldba";
    repo = "postgres-mcp";
    tag = "v${version}";
    hash = "sha256-VCU7qVPbYyBBkLwtmNf+I0XxGzY4Qd7JFHEwbI8eU+I=";
  };

  build-system = [ python3Packages.hatchling ];

  pythonRelaxDeps = [ "pglast" ];

  dependencies = with python3Packages; [
    mcp
    psycopg
    psycopg-pool
    humanize
    pglast
    attrs
    instructor
  ];

  pythonImportsCheck = [ "postgres_mcp" ];

  # dev-only deps (pytest, docker) pull heavy trees and need a live database.
  doCheck = false;

  meta = {
    description = "PostgreSQL MCP server with read-only restricted mode and performance analysis";
    homepage = "https://github.com/crystaldba/postgres-mcp";
    license = lib.licenses.mit;
    mainProgram = "postgres-mcp";
  };
}
