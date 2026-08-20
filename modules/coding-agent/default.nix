{
  config,
  options,
  pkgs,
  lib,
  ...
}:
let
  # The module takes no special args (no pkgsUnstable): the pinned/unstable
  # packages (pi-coding-agent, agent-browser, the mcp-* servers) are sourced
  # from nixpkgs-unstable by this flake's overlay (overlays/coding-agent.nix),
  # which the user's own hosts apply via modules/base. Consumers without the
  # overlay get whatever their nixpkgs provides.
  #
  # NOTE: this module is NOT standalone. It writes the agent config files via
  # home-manager.users.<user>.home.file, so the host MUST also import
  # home-manager.nixosModules.home-manager (coltrane does, via hive.nix). The
  # assertion below fails loudly if that import is missing.
  buildExts = import ./build-extensions.nix { inherit pkgs; };
  wrapperLib = import ./wrapper.nix { inherit pkgs; };
  registry = import ./mcp-registry.nix { inherit pkgs; };
  # Plugin packs (superpowers + ponytail) - loaded as pi extensions / Claude plugins
  # one fetch in plugins.nix, used by both.
  plugins = import ./plugins.nix { inherit pkgs; };
  superpowers = plugins.superpowers;
  ponytail = plugins.ponytail;
  # SSH-tunnel MCP builders, promoted from the coltrane host config so any
  # host can reach non-network-exposed postgres/redis over ssh(1).
  tunnels = import ./ssh-tunnels.nix { inherit pkgs lib; };
  httpMcp = import ./http-mcp.nix { inherit pkgs; };
in
{
  imports = [
    ./claude.nix
    ./skills.nix
    ./mcp-servers.nix
  ];

  options.codingAgent = {
    enable = lib.mkEnableOption "Enable the Coding Agent environment";
    user = lib.mkOption {
      type = lib.types.str;
      description = "The user for whom to configure the agent. Empty = first normal user.";
      default = "";
    };
    theme = lib.mkOption {
      type = lib.types.attrs;
      description = "Theme configuration for the agent";
      default = {
        "$schema" =
          "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
        name = "dracula";
        vars = {
          bg = "#282a36";
          currentLine = "#44475a";
          fg = "#f8f8f2";
          comment = "#6272a4";
          cyan = "#8be9fd";
          green = "#50fa7b";
          orange = "#ffb86c";
          pink = "#ff79c6";
          purple = "#bd93f9";
          red = "#ff5555";
          yellow = "#f1fa8c";
        };
        colors = {
          accent = "purple";
          border = "comment";
          borderAccent = "purple";
          borderMuted = "currentLine";
          success = "green";
          error = "red";
          warning = "yellow";
          muted = "comment";
          dim = 240;
          text = "";
          thinkingText = "comment";
          selectedBg = "currentLine";
          userMessageBg = "currentLine";
          userMessageText = "";
          customMessageBg = "currentLine";
          customMessageText = "";
          customMessageLabel = "purple";
          toolPendingBg = "#21222c";
          toolSuccessBg = "#1e2b22";
          toolErrorBg = "#2d1f22";
          toolTitle = "purple";
          toolOutput = "";
          mdHeading = "purple";
          mdLink = "cyan";
          mdLinkUrl = "comment";
          mdCode = "green";
          mdCodeBlock = "";
          mdCodeBlockBorder = "comment";
          mdQuote = "comment";
          mdQuoteBorder = "purple";
          mdHr = "comment";
          mdListBullet = "pink";
          toolDiffAdded = "green";
          toolDiffRemoved = "red";
          toolDiffContext = "comment";
          syntaxComment = "comment";
          syntaxKeyword = "pink";
          syntaxFunction = "green";
          syntaxVariable = "fg";
          syntaxString = "yellow";
          syntaxNumber = "purple";
          syntaxType = "cyan";
          syntaxOperator = "pink";
          syntaxPunctuation = "fg";
          thinkingOff = "comment";
          thinkingMinimal = "cyan";
          thinkingLow = "green";
          thinkingMedium = "yellow";
          thinkingHigh = "orange";
          thinkingXhigh = "pink";
          bashMode = "orange";
        };
        export = {
          pageBg = "#21222c";
          cardBg = "#282a36";
          infoBg = "#44475a";
        };
      };
    };
    models = lib.mkOption {
      type = lib.types.attrs;
      description = "Model providers and model definitions";
      default = {
        providers = { };
      };
    };
    settings = lib.mkOption {
      type = lib.types.attrs;
      description = "General agent settings";
      default = { };
    };

    _resolved = lib.mkOption {
      internal = true;
      type = lib.types.attrs;
      description = "Flattened MCP server map resolved from the declarative catalog.";
    };

    _effectiveUser = lib.mkOption {
      internal = true;
      type = lib.types.str;
      description = "The effective agent user (explicit or first normal user).";
    };
  };

  config =
    let
      cfg = config.codingAgent;

      # Explicit user, or the first normal user. Never hardcoded to marv.
      effectiveUser =
        if cfg.user != "" then
          cfg.user
        else
          lib.head (
            lib.filter (u: config.users.users.${u}.isNormalUser or false) (
              builtins.attrNames config.users.users
            )
          );

      # Resolve a single server to {bin, command, args, env}. The registry is
      # the source of truth for `bin`/`command`; a raw entry may override both
      # (the ssh-tunnel builders supply a bespoke bin + command name). Every
      # server goes through the wrapper: it scrubs the inherited Python env
      # (so a bundled-Python server like mcp-nixos uses its own interpreter
      # regardless of the launching shell) and injects any `*_FILE` secret
      # (the sops-nix convention). Servers with no `*_FILE` env keys just get
      # the env scrub — a no-op secret pass.
      mkWrapped =
        name:
        {
          bin ? null,
          command ? null,
          args ? [ ],
          env ? { },
        }:
        let
          serverDef =
            registry.mcpRegistry."${name}" or {
              bin = null;
              command = name;
            };
          useBin = if bin != null then bin else serverDef.bin;
          useCommand = if command != null then command else serverDef.command;
        in
        {
          inherit args env;
          command = useCommand;
          bin =
            if useBin != null then
              wrapperLib.mkSecretWrapper {
                bin = useBin;
                command = useCommand;
                env = env;
              }
            else
              useBin;
        };

      # uid of the effective user, for the tmpfs playwright profile path.
      # `isNormalUser` leaves uid null at eval time, so fall back to 1000
      # (the auto-allocated value on a single-user host) when it's null.
      uid =
        if config.users.users."${effectiveUser}".uid != null then
          config.users.users."${effectiveUser}".uid
        else
          1000;

      # --- Declarative catalog: named servers with their args/env. ---
      # Non-secret, hardware-agnostic servers are enabled by default (their
      # enable flags default true in mcp-servers.nix). Secret/hardware-bound
      # ones are opt-in via their enable flag.
      catalogRaw =
        lib.optional cfg.mcpServers.git { name = "git"; }
        ++ lib.optional cfg.mcpServers.nixos { name = "nixos"; }
        ++ lib.optional cfg.mcpServers.context7 { name = "context7"; }
        ++ lib.optional cfg.mcpServers.sequentialThinking { name = "sequential-thinking"; }
        ++ lib.optional cfg.mcpServers.github.enable {
          name = "github";
          args = [ "stdio" ];
          env = lib.optionalAttrs (cfg.mcpServers.github.tokenFile != null) {
            GITHUB_PERSONAL_ACCESS_TOKEN_FILE = cfg.mcpServers.github.tokenFile;
          };
        }
        ++ lib.optional cfg.mcpServers.memory.enable {
          name = "memory";
          env = {
            MEMORY_FILE_PATH = cfg.mcpServers.memory.filePath;
          };
        }
        ++ lib.optional cfg.mcpServers.playwright.enable {
          name = "playwright";
          args = [
            "--extension"
            "--executable-path"
            cfg.mcpServers.playwright.chromePath
          ];
          env = {
            PWTEST_EXTENSION_USER_DATA_DIR = cfg.mcpServers.playwright.userDataDir;
            PLAYWRIGHT_MCP_USER_DATA_DIR = "/run/user/${toString uid}/playwright-mcp-profile";
          };
        };

      # --- SSH-tunneled catalog: one entry per named postgres/redis. ---
      sshRaw =
        lib.concatLists (
          lib.mapAttrsToList (
            name: s:
            lib.optional s.enable {
              name = "postgres-${name}";
              command = "postgres-${name}";
              bin = tunnels.postgresForward {
                host = s.host;
                db = s.db;
                sshUser = s.sshUser;
                sshOptions = s.sshOptions;
              };
            }
          ) cfg.mcpServers.sshPostgres
        )
        ++ lib.concatLists (
          lib.mapAttrsToList (
            name: s:
            lib.optional s.enable {
              name = "redis-${name}";
              command = "redis-${name}";
              bin = tunnels.redisForward {
                host = s.host;
                sshUser = s.sshUser;
                sshOptions = s.sshOptions;
              };
            }
          ) cfg.mcpServers.sshRedis
        )
        ++ lib.concatLists (
          lib.mapAttrsToList (
            name: s:
            lib.optional s.enable {
              name = name;
              command = s.command or "httpBasic-${name}";
              bin = httpMcp.basicAuthWrapper {
                name = "httpBasic-${name}";
                urlVar = s.urlVar;
                userVar = s.userVar;
                passVar = s.passVar;
                urlSuffix = s.urlSuffix;
              };
              env = {
                "${s.urlVar}_FILE" = s.urlFile;
                "${s.userVar}_FILE" = s.usernameFile;
                "${s.passVar}_FILE" = s.passwordFile;
              };
            }
          ) cfg.mcpServers.httpBasic
        )
        ++ lib.concatLists (
          lib.mapAttrsToList (
            name: s:
            lib.optional s.enable {
              # The mcp.json key is the catalog name = the registry key
              # (grafana-viz-mon, confluence, youtrack, ...). The registry
              # provides bin/command; only args + env differ per host.
              name = name;
              args = s.args;
              env = s.extraEnv // s.secretEnv;
            }
          ) cfg.mcpServers.httpToken
        );

      # Resolve each catalog entry once; both the package list and the
      # mcp.json manifest derive from this so the (potentially expensive)
      # wrapper derivation is built a single time per server. Entries carry
      # `name` + a spec; fold into a name -> spec map first (listToAttrs needs
      # {name,value} pairs), then wrap each.
      catalogMap = lib.listToAttrs (
        map (e: {
          name = e.name;
          value = lib.removeAttrs e [ "name" ];
        }) (catalogRaw ++ sshRaw)
      );
      resolved = lib.mapAttrs mkWrapped catalogMap;

      # Raw `extra` entries (backward compat with the old free-form shape)
      # overlay the catalog.
      extraResolved = lib.mapAttrs mkWrapped cfg.mcpServers.extra;

      mcpPackages = lib.mapAttrs (_: r: r.bin) (resolved // extraResolved);

      # The final bundled package
      codingAgentWithExtensions = pkgs.symlinkJoin {
        name = "coding-agent-with-extensions";
        paths = [
          pkgs.pi-coding-agent
          pkgs.agent-browser
          buildExts.permissionSystem
          buildExts.mcpAdapter
          buildExts.browserTools
          # NOTE: `gh` is deliberately NOT bundled here. It is the one tool
          # that needs a host secret (an auth token), so the host provides an
          # authenticated `gh` on the system PATH; the agent inherits it. The
          # sops-reading `gh` wrapper lives in overlays/default.nix and is
          # installed via home-manager/modules/base.nix.
          pkgs.ripgrep
        ]
        # lib.unique: two MCP servers sharing the same binary + identical
        # `*_FILE` env keys (e.g. the two Grafana instances) produce the SAME
        # wrapper store path; dedupe so symlinkJoin doesn't see it twice.
        ++ lib.unique (lib.filter (x: x != null) (lib.attrValues mcpPackages));
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/pi \
            --add-flags "--extension ${buildExts.permissionSystem}/lib/pi-permission-system/src/index.ts" \
            --add-flags "--extension ${buildExts.mcpAdapter}/index.ts" \
            --add-flags "--extension ${buildExts.browserTools}/extensions/browser-tools/index.ts" \
            --add-flags "--extension ${superpowers}/.pi/extensions/superpowers.ts" \
            --add-flags "--extension ${ponytail}/pi-extension/index.js"
        '';
      };

    in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = options ? home-manager;
          message = ''
            codingAgent requires home-manager.nixosModules.home-manager to be
            imported on this host (it writes the agent config under the user's home
            via home-manager.users.${effectiveUser}.home.file).
          '';
        }
      ];

      # Expose the resolved server map + effective user to other modules
      # (claude.nix reads _effectiveUser).
      codingAgent._resolved = resolved // extraResolved;
      codingAgent._effectiveUser = effectiveUser;

      environment.systemPackages = [
        codingAgentWithExtensions
      ];

      home-manager.users.${effectiveUser}.home.file = {
        ".pi/agent/models.json" = {
          text = builtins.toJSON cfg.models;
          force = true;
        };
        ".pi/agent/themes/theme.json" = {
          text = builtins.toJSON cfg.theme;
          force = true;
        };
        ".pi/agent/settings.json" = {
          # Add ponytail's skills dir to pi's search path; the extension activates
          # the mode/aliases, but the manifest requires explicit dir registration.
          text = builtins.toJSON (
            cfg.settings
            // {
              skills = (cfg.settings.skills or [ ]) ++ [ "${ponytail}/skills" ];
            }
          );
          force = true;
        };
        ".pi/agent/mcp.json" = {
          text = builtins.toJSON {
            mcpServers = lib.mapAttrs (_: r: {
              inherit (r) command args env;
            }) (resolved // extraResolved);
          };
          force = true;
        };
      };
    };
}
