{ lib, ... }:
let
  # A secret-file path option. The module never reads the secret itself —
  # only the path. Coworkers set it to config.sops.secrets.<name>.path.
  srv = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Path to the secret file (e.g. config.sops.secrets.<name>.path).";
  };

  # Shared options for SSH-tunneled servers.
  sshServer = {
    options = {
      enable = lib.mkEnableOption "this SSH-forwarded MCP server";
      host = lib.mkOption {
        type = lib.types.str;
        description = "SSH target hostname.";
      };
      sshUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "SSH user for the target host. Null = ssh(1) default user (current user).";
      };
      sshOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra ssh(1) options.";
      };
    };
  };
in
{
  options.codingAgent.mcpServers = lib.mkOption {
    type = lib.types.submodule {
      options = {
        # Basic, non-secret, hardware-agnostic servers — enabled by default.
        git = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the git MCP server.";
        };
        nixos = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the nixos MCP server.";
        };
        context7 = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the context7 MCP server.";
        };
        sequentialThinking = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the sequential-thinking MCP server.";
        };

        github = {
          enable = lib.mkEnableOption "github MCP server";
          tokenFile = srv;
        };
        playwright = {
          enable = lib.mkEnableOption "playwright MCP server";
          chromePath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to a chromium binary (for --executable-path).";
          };
          userDataDir = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to the Chromium user-data-dir/profile.";
          };
        };
        memory = {
          enable = lib.mkEnableOption "memory MCP server";
          filePath = lib.mkOption {
            type = lib.types.str;
            default = "~/.pi/agent/memory.jsonl";
          };
        };

        sshPostgres = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule (
              lib.recursiveUpdate sshServer {
                options.db = lib.mkOption {
                  type = lib.types.str;
                  description = "Database name to connect to.";
                };
              }
            )
          );
          default = { };
        };
        sshRedis = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule sshServer);
          default = { };
        };
        httpBasic = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "this HTTP basic-auth MCP server";
                urlFile = srv;
                usernameFile = srv;
                passwordFile = srv;
                command = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Override binary name (for a bespoke wrapper).";
                };
                # Env var names the wrapper reads (after *_FILE stripping), so
                # a host can keep existing names without changing its mcp.json.
                urlVar = lib.mkOption {
                  type = lib.types.str;
                  default = "URL";
                  description = "Env var holding the base URL.";
                };
                userVar = lib.mkOption {
                  type = lib.types.str;
                  default = "USERNAME";
                  description = "Env var holding the basic-auth username.";
                };
                passVar = lib.mkOption {
                  type = lib.types.str;
                  default = "PASSWORD";
                  description = "Env var holding the basic-auth password.";
                };
                urlSuffix = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  description = "Suffix appended to the base URL (e.g. the server's /mcp path).";
                };
              };
            }
          );
          default = { };
        };

        # HTTP servers authenticated with a bearer token / personal-access-token
        # (grafana, confluence, youtrack). The registry maps `name` -> bin/command;
        # secretFile carries `*_FILE` env keys (sops paths) injected by the secret
        # wrapper; extraEnv holds plain env (e.g. GRAFANA_ORG_ID).
        httpToken = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "this HTTP token/PAT MCP server";
                args = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Extra CLI args for the server.";
                };
                secretEnv = lib.mkOption {
                  type = lib.types.attrsOf lib.types.str;
                  default = { };
                  description = "*_FILE env keys -> secret file paths (auto-injected by the secret wrapper).";
                };
                extraEnv = lib.mkOption {
                  type = lib.types.attrsOf lib.types.str;
                  default = { };
                  description = "Plain (non-secret) env vars.";
                };
              };
            }
          );
          default = { };
        };

        # Raw escape hatch, backward-compatible with the old free-form shape.
        extra = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Raw MCP server entries ({bin,command,args,env}); merged last.";
        };
      };
    };
  };
}
