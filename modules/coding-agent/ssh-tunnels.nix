{ pkgs, lib }:
let
  # Build the ssh(1) target: "user@host" if a user is given, else just host.
  target = host: user: if user == null then host else "${user}@${host}";
in
{
  # SSH-forwarded read-only Postgres MCP.
  # Forwards the remote postgres unix socket over a per-instance temp dir
  # (NOT a fixed TCP port: a fixed port can only be bound by ONE client, so
  # pi + Claude sharing mcp.json would collide — the second ssh -L aborts on
  # ExitOnForwardFailure). Connect as `postgres` (socket's `local all all
  # trust` rule). Restricted access rejects writes at parse time.
  # Runs in the foreground; NOT exec'd so the EXIT trap closes the tunnel.
  postgresForward =
    {
      host,
      db,
      sshUser ? null,
      sshOptions ? [ ],
    }:
    let
      opts = lib.escapeShellArgs sshOptions;
    in
    pkgs.writeShellApplication {
      name = "postgres-${db}-${host}";
      runtimeInputs = [
        pkgs.openssh
        pkgs.postgres-mcp
      ];
      text = ''
        CTL="$(mktemp -u)"
        SOCKDIR="$(mktemp -d)"
        cleanup() {
          ssh -S "$CTL" -O exit ${target host sshUser} 2>/dev/null || true
          rm -rf "$SOCKDIR"
        }
        trap cleanup EXIT

        ssh -f -N -M -S "$CTL" -o ExitOnForwardFailure=yes ${opts} \
          -L "$SOCKDIR/.s.PGSQL.5432:/run/postgresql/.s.PGSQL.5432" ${target host sshUser}

        postgres-mcp --access-mode restricted "postgresql://postgres@/${db}?host=$SOCKDIR"
      '';
    };

  # SSH-forwarded read-only Redis MCP. Forwards 127.0.0.1:6379 into a
  # per-instance RANDOM local port (retried up to 20x on collision; redis has
  # no unix-socket support). Runs in the foreground; NOT exec'd so the EXIT
  # trap closes the tunnel. Write tools are patched out of redis-mcp-server
  # (pkgs/redis-mcp-readonly.patch).
  redisForward =
    {
      host,
      sshUser ? null,
      sshOptions ? [ ],
    }:
    let
      opts = lib.escapeShellArgs sshOptions;
    in
    pkgs.writeShellApplication {
      name = "redis-${host}";
      runtimeInputs = [
        pkgs.openssh
        pkgs.redis-mcp-server
      ];
      text = ''
        CTL="$(mktemp -u)"
        cleanup() {
          ssh -S "$CTL" -O exit ${target host sshUser} 2>/dev/null || true
        }
        trap cleanup EXIT

        PORT=""
        for _ in $(seq 1 20); do
          P=$(( (RANDOM % 20000) + 20000 ))
          if ssh -f -N -M -S "$CTL" -o ExitOnForwardFailure=yes ${opts} \
              -L "127.0.0.1:$P:127.0.0.1:6379" ${target host sshUser} 2>/dev/null; then
            PORT=$P
            break
          fi
        done
        [ -n "$PORT" ] || { echo "could not bind a local port" >&2; exit 1; }

        redis-mcp-server --host 127.0.0.1 --port "$PORT"
      '';
    };
}
