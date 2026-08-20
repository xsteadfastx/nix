{ pkgs }:
# Pure (no-VM) check for the declarative MCP catalog
# (modules/coding-agent/mcp-servers.nix). Evaluates the submodule in isolation
# and asserts:
#   * the four basic (non-secret, hardware-agnostic) servers default to enabled;
#   * secret-bound servers default to disabled;
#   * a host definition enabling an sshPostgres entry resolves host/db/sshUser;
#   * the raw `extra` escape hatch still accepts the old free-form shape.
# This is the option-surface logic the coworker-facing API depends on.
let
  lib = pkgs.lib;
  mcp = import ./mcp-servers.nix { inherit lib; };
  # bool -> "true"/"false" for shell comparisons (toString gives 1/empty).
  b = v: if v then "true" else "false";

  eval =
    defs:
    lib.evalModules {
      modules = [
        mcp
        { config.xsfx.codingAgent.mcpServers = defs; }
      ];
    };

  # Defaults, no host definition.
  defaults = (eval { }).config.xsfx.codingAgent.mcpServers;

  # Host definition: enables a postgres tunnel + github with a token path,
  # plus an `extra` raw entry in the old shape.
  host =
    (eval {
      github.enable = true;
      github.tokenFile = "/run/secrets/gh";
      sshPostgres."mydb-myhost" = {
        enable = true;
        host = "myhost";
        db = "mydb";
      };
      extra.myserver = {
        args = [ "stdio" ];
        env = {
          MY_TOKEN_FILE = "/run/secrets/tok";
        };
      };
    }).config.xsfx.codingAgent.mcpServers;

  checks = pkgs.writeShellScript "checks" ''
    set -e
    # Defaults: basic servers on, secret-bound off.
    test "${b defaults.git}" = true
    test "${b defaults.nixos}" = true
    test "${b defaults.context7}" = true
    test "${b defaults.sequentialThinking}" = true
    test "${b defaults.github.enable}" = false
    test "${b defaults.playwright.enable}" = false

    # Host definition: explicit github token + sshPostgres resolve.
    test "${b host.github.enable}" = true
    test "${host.github.tokenFile}" = "/run/secrets/gh"
    test "${b host.sshPostgres."mydb-myhost".enable}" = true
    test "${host.sshPostgres."mydb-myhost".host}" = "myhost"
    test "${host.sshPostgres."mydb-myhost".db}" = "mydb"

    # sshUser defaults null (ssh(1) default user) -> toString is empty.
    test -z "${builtins.toString host.sshPostgres."mydb-myhost".sshUser}"

    # Raw escape hatch still parses; args is a list of strings.
    test "${builtins.elemAt host.extra.myserver.args 0}" = "stdio"
    echo ok
  '';
in
pkgs.runCommand "coding-agent-mcp-check" { } ''
  ${checks}
  echo ok > $out
''
