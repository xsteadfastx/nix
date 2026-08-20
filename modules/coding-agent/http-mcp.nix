{ pkgs }:
# HTTP MCP servers. A remote server hosted behind basic-auth (e.g. hemingway's
# in-process /mcp endpoint) is bridged to stdio via mcp-proxy, but mcp-proxy
# has no native basic-auth option (only `-H KEY VALUE` or the `API_ACCESS_TOKEN`
# Bearer shortcut). This wrapper builds `Authorization: Basic <b64(user:pass)>`
# from the three real env vars — already exported by the module's secret wrapper
# from their *_FILE counterparts — and execs mcp-proxy with the header as a
# SINGLE argv element. `urlVar` holds the base URL; `urlSuffix` is appended
# (e.g. the server's /mcp path).
#
# The env var names are built with Nix string concatenation ("$" + name) rather
# than escaping inside the indented string, because Nix's `\$${name}` in an
# indented string emits a literal `\$${name}` — the interpolation is swallowed
# — which breaks the wrapper.
{
  basicAuthWrapper =
    {
      name,
      urlVar,
      userVar,
      passVar,
      urlSuffix ? "",
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.mcp-proxy
        pkgs.coreutils
      ];
      text = ''
        set -euo pipefail
        AUTH="Basic $(printf '%s:%s' "$''
      + userVar
      + ''" "$''
      + passVar
      + ''
        " | base64 -w0)"
                  exec mcp-proxy --transport streamablehttp -H Authorization "$AUTH" "$''
      + urlVar
      + urlSuffix
      + ''
        "
      '';
    };
}
