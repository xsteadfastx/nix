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
  options.xsfx.codingAgent.mcpServers = lib.mkOption {
    type = lib.types.submodule {
      options = {
        git = lib.mkEnableOption "git MCP server";
        nixos = lib.mkEnableOption "nixos MCP server";
        context7 = lib.mkEnableOption "context7 MCP server";
        sequentialThinking = lib.mkEnableOption "sequential-thinking MCP server";

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
              sshServer
              // {
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
    default = {
      git = true;
      nixos = true;
      context7 = true;
      sequentialThinking = true;
    };
  };
}
