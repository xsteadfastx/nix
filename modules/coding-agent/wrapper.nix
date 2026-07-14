{ pkgs, ... }:
{
  # Wrap an MCP server binary so secrets can be injected from files using the
  # standard `_FILE` convention (sops-nix / 12-factor): for every env var
  # whose name ends in `_FILE`, if it points at a readable file, export the
  # var with the `_FILE` suffix stripped (e.g. GRAFANA_URL_FILE -> GRAFANA_URL)
  # before exec'ing the real binary. Plain env vars pass through untouched.
  #
  # Used for grafana, whose upstream binary ignores the `*_FILE` vars and 401s
  # unless the real credentials are exported directly.
  #
  # `bin` is the package derivation; `command` is the binary name both to
  # expose (the wrapper's argv[0]) and to exec (bin/bin/<command>). `env` is
  # read only for its keys — the actual file paths arrive at runtime via the
  # process environment (set by pi from mcp.json).
  mkSecretWrapper =
    {
      bin,
      command,
      env,
    }:
    let
      fileVars = pkgs.lib.filter (k: pkgs.lib.hasSuffix "_FILE" k) (pkgs.lib.attrNames env);
      exportLines = map (
        fileVar:
        let
          realVar = pkgs.lib.removeSuffix "_FILE" fileVar;
        in
        # shell, not nix: $<fileVar> and $(cat ...) stay literal
        "if [ -n \"\$${fileVar}\" ] && [ -f \"\$${fileVar}\" ]; then export ${realVar}=\$(cat \"\$${fileVar}\"); fi"
      ) fileVars;
      script = pkgs.lib.concatStringsSep "\n" (
        [
          "# Auto-generated MCP Secret Wrapper"
          # MCP servers inherit the agent's environment, and the agent may be
          # launched from a dev shell (direnv + pre-commit) that exports a
          # PYTHONPATH pinned to a *different* Python than a bundled server's own
          # interpreter. Inheriting it makes e.g. mcp-proxy import a mismatched
          # pydantic_core C extension and crash on startup (surfaces as a
          # JSON-RPC -32000 "failed to reconnect"). Scrub it so every wrapped
          # server uses its own closure's Python, regardless of launching shell.
          # PYTHONNOUSERSITE is scrubbed too so a leaked ~/.local/lib can't shadow
          # the closure either.
          "unset PYTHONPATH PYTHONHOME PYTHONNOUSERSITE"
        ]
        ++ exportLines
        ++ [
          # `eval` so args like "$YOUTRACK_URL" (passed literally by the agent)
          # are expanded after the export lines above have populated them.
          "eval exec ${bin}/bin/${command} \"\$@\""
        ]
      );
    in
    pkgs.writeShellScriptBin command script;
}
