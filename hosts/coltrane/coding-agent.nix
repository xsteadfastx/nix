{ config, ... }:
{
  codingAgent.enable = true;

  # Auto-discover models from the live ollama servers on every pi/claude
  # launch (context windows, reasoning, vision are derived from the API,
  # not hand-maintained). The local server caps context at 32768 (its
  # OLLAMA_CONTEXT_LENGTH); wobcom serves full native context.
  codingAgent.ollamaServers = [
    {
      name = "ollama-local";
      baseUrl = "http://127.0.0.1:11434/v1";
      apiKey = "ollama";
      contextCap = 32768;
    }
    {
      name = "ollama-wobcom";
      baseUrl = "http://ollama.service.wobcom.de:11434/v1";
      apiKey = "ollama";
    }
  ];
  codingAgent.settings = {
    autoCompactionEnabled = true;
    defaultProvider = "ollama-wobcom";
    defaultModel = "gemma4:31b";
    theme = "dracula";
    skills = [ "/home/marv/.claude/skills" ];
  };

  # MCP servers. A bare entry is enough for non-secret servers: the module's
  # registry resolves `bin` and `command` from pkgs. Grafana needs its sops
  # secrets injected — any `*_FILE` env var is auto-translated into the real
  # var (suffix stripped) at exec time (modules/coding-agent/wrapper.nix).
  # Calls are locked read-only via `--disable-write`.
  # MCP servers via the declarative catalog. `git`, `nixos`, `context7` and
  # `sequential-thinking` are enabled by default (non-secret, hardware-
  # agnostic), so they need no entry here. Secret-bound and infra servers are
  # enabled explicitly below; grafana/confluence/youtrack/hemingway are bespoke
  # and stay as raw `extra` entries.
  codingAgent.mcpServers = {
    github = {
      enable = true;
      tokenFile = config.sops.secrets."gh-token".path;
    };
    playwright = {
      enable = true;
      chromePath = "/home/marv/.nix-profile/bin/chromium";
      userDataDir = "/home/marv/.config/chromium";
    };
    memory = {
      enable = true;
      # Absolute (fs.writeFile doesn't mkdir/expand ~).
      filePath = "/home/marv/.pi/agent/memory.jsonl";
    };
    sshPostgres."hemingway-barletta" = {
      enable = true;
      host = "barletta";
      db = "hemingway";
    };
    sshPostgres."chirpas-kirchart" = {
      enable = true;
      host = "kirchart";
      db = "chirpas";
    };
    sshPostgres."chirpns-kirchart" = {
      enable = true;
      host = "kirchart";
      db = "chirpns";
    };
    sshRedis.kirchart = {
      enable = true;
      host = "kirchart";
    };
    # Hemingway MCP: in-process /mcp on the deployed API (StreamableHTTP,
    # behind Caddy basic_auth). httpBasic builds the Basic auth header via
    # mcp-proxy; the var names match hemingway's existing env so mcp.json is
    # unchanged.
    httpBasic.hemingway = {
      enable = true;
      urlFile = config.sops.secrets."mcp-hemingway-url".path;
      usernameFile = config.sops.secrets."mcp-hemingway-username".path;
      passwordFile = config.sops.secrets."mcp-hemingway-password".path;
      command = "hemingway-mcp";
      urlVar = "HEMINGWAY_SERVICES_API";
      userVar = "HEMINGWAY_MCP_USERNAME";
      passVar = "HEMINGWAY_MCP_PASSWORD";
      urlSuffix = "/mcp";
    };

    # HTTP token/PAT servers (bearer auth, distinct from hemingway's basic
    # auth). The registry maps the catalog name to bin/command; only args +
    # env differ per host. secretEnv carries the *_FILE sops paths (auto-\
    # injected by the secret wrapper); extraEnv holds plain env (GRAFANA_ORG_ID).
    httpToken = {
      grafana-viz-mon = {
        enable = true;
        args = [
          "--disable-write"
          "-debug"
        ];
        secretEnv = {
          GRAFANA_URL_FILE = config.sops.secrets."mcp-grafana-url".path;
          GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = config.sops.secrets."mcp-grafana-token".path;
        };
        extraEnv.GRAFANA_ORG_ID = "1";
      };
      grafana-viz = {
        enable = true;
        args = [ "--disable-write" ];
        secretEnv = {
          GRAFANA_URL_FILE = config.sops.secrets."mcp-grafana-viz-url".path;
          GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = config.sops.secrets."mcp-grafana-viz-token".path;
        };
        extraEnv.GRAFANA_ORG_ID = "1";
      };
      # Confluence Data Center, read-only via PAT.
      confluence = {
        enable = true;
        args = [ "--read-only" ];
        secretEnv = {
          CONFLUENCE_URL_FILE = config.sops.secrets."mcp-confluence-url".path;
          CONFLUENCE_PERSONAL_TOKEN_FILE = config.sops.secrets."mcp-confluence-token".path;
        };
      };
      # YouTrack remote MCP over StreamableHTTP, Bearer token via mcp-proxy.
      youtrack = {
        enable = true;
        args = [
          "--transport"
          "streamablehttp"
          "$YOUTRACK_URL"
        ];
        secretEnv = {
          YOUTRACK_URL_FILE = config.sops.secrets."mcp-youtrack-url".path;
          API_ACCESS_TOKEN_FILE = config.sops.secrets."mcp-youtrack-token".path;
        };
      };
    };
  };
}
