{ pkgs }:
# Pure (no-VM) check for the MCP secret wrapper
# (modules/coding-agent/wrapper.nix). Wraps a fake server whose only job is to
# print the env vars a real mcp-grafana would consume, points the *_FILE env
# vars at temp secret files, runs the wrapper, and asserts the wrapper
# translated the file contents into the real credentials before exec. This is
# the subtle, hand-rolled logic most likely to silently regress.
let
  wrapperLib = import ./wrapper.nix { inherit pkgs; };

  # Stand-in for mcp-grafana: echo the vars we expect the wrapper to inject.
  fakeServer = pkgs.writeShellScriptBin "mcp-grafana" ''
    echo "URL=$GRAFANA_URL"
    echo "TOKEN=$GRAFANA_SERVICE_ACCOUNT_TOKEN"
    echo "ORG=$GRAFANA_ORG_ID"
  '';

  # `env` carries the *_FILE keys (the wrapper reads only their names to know
  # which vars to translate) plus a plain passthrough value. Real file paths
  # arrive at runtime via the environment, set here by the test driver.
  wrapped = wrapperLib.mkSecretWrapper {
    bin = fakeServer;
    command = "mcp-grafana";
    env = {
      GRAFANA_URL_FILE = "";
      GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = "";
      GRAFANA_ORG_ID = "1";
    };
  };
in
pkgs.runCommand "coding-agent-wrapper-test" { } ''
  mkdir -p $out

  # Secret material lives in files (the sops-nix pattern).
  printf 'https://grafana.example.test' > url.secret
  printf 'tok-abc-123' > token.secret

  export GRAFANA_URL_FILE="$PWD/url.secret"
  export GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE="$PWD/token.secret"
  export GRAFANA_ORG_ID=1

  res=$(${wrapped}/bin/mcp-grafana)
  echo "$res"

  grep -qx 'URL=https://grafana.example.test' <<<"$res" || {
    echo "FAIL: GRAFANA_URL not translated from *_FILE" >&2
    exit 1
  }
  grep -qx 'TOKEN=tok-abc-123' <<<"$res" || {
    echo "FAIL: GRAFANA_SERVICE_ACCOUNT_TOKEN not translated from *_FILE" >&2
    exit 1
  }
  grep -qx 'ORG=1' <<<"$res" || {
    echo "FAIL: passthrough env var GRAFANA_ORG_ID missing" >&2
    exit 1
  }

  # Negative path: an unset *_FILE must leave the var empty (wrapper guards
  # with [ -n ] && [ -f ]), not error.
  unset GRAFANA_URL_FILE
  res2=$(${wrapped}/bin/mcp-grafana)
  echo "$res2"
  grep -qx 'URL=' <<<"$res2" || {
    echo "FAIL: unset *_FILE should leave GRAFANA_URL empty" >&2
    exit 1
  }

  touch $out/pass
''
