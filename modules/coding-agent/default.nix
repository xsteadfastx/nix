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
in
{
  imports = [
    ./claude.nix
    ./skills.nix
  ];

  options.xsfx.codingAgent = {
    enable = lib.mkEnableOption "Enable the Coding Agent environment";
    user = lib.mkOption {
      type = lib.types.str;
      description = "The user for whom to configure the agent";
      default = "marv";
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
        providers = {
          ollama-local = {
            baseUrl = "http://127.0.0.1:11434/v1";
            api = "openai-completions";
            apiKey = "ollama";
            compat = {
              supportsDeveloperRole = false;
              supportsReasoningEffort = false;
            };
            models = [
              {
                id = "qwen3.5";
                name = "Qwen 3.5 9B";
                reasoning = true;
                input = [ "text" ];
                contextWindow = 65536;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
                compat.thinkingFormat = "qwen-chat-template";
              }
              {
                id = "glm-4.7-flash";
                name = "GLM 4.7 Flash";
                reasoning = true;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "glm-5.2:cloud";
                name = "GLM 5.2 Cloud";
                reasoning = true;
                input = [ "text" ];
                contextWindow = 1000000;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "qwen2.5-coder:14b";
                name = "Qwen 2.5 Coder 14B";
                reasoning = false;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                # Small non-reasoning coder that fully fits the Arc iGPU; the
                # offline workhorse behind the `pi-offline` wrapper. Native
                # context is 32768, matching the local ollama server.
                id = "qwen2.5-coder:7b";
                name = "Qwen 2.5 Coder 7B";
                reasoning = false;
                input = [ "text" ];
                contextWindow = 32768;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                # Ornith 9B — agentic-coding-tuned (Terminal-Bench/SWE-Bench),
                # MIT. At ~5.6 GB it fully offloads to the Arc iGPU under normal
                # desktop RAM pressure (unlike gemma4:12b/qwen3-coder:30b), so
                # it's the candidate offline agent that both fits AND may drive
                # pi's tool loop where qwen2.5-coder:7b emits text-JSON. Pull with
                # `ollama pull ornith:9b`. reasoning = true: the model card says it
                # "thinks step by step in a reasoning block", so pi must parse the
                # thinking channel (same as gemma4:12b, else empty content).
                # contextWindow MUST stay 32768 to match OLLAMA_CONTEXT_LENGTH —
                # see qwen3-coder:30b warning. (35B variant omitted: ~21 GB won't
                # fit the iGPU on this 30 GB laptop.)
                id = "ornith:9b";
                name = "Ornith 9B";
                reasoning = true;
                input = [ "text" ];
                contextWindow = 32768;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "kimi-k2.7-code:cloud";
                name = "Kimi K2.7 Code";
                reasoning = true;
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 262144;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "qwen3-coder:480b-cloud";
                name = "Qwen 3 Coder 480B Cloud";
                reasoning = false;
                input = [ "text" ];
                contextWindow = 262144;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "qwen3-coder:30b";
                name = "Qwen 3 Coder 30B";
                reasoning = false;
                input = [ "text" ];
                # MUST equal ollama's OLLAMA_CONTEXT_LENGTH (32768 in
                # hosts/coltrane/ollama.nix). The /v1 endpoint has no num_ctx
                # field, so this is purely pi's prompt budget: set it higher and
                # pi packs prompts past the server window, forcing llama-server
                # to build oversized SYCL compute buffers on the shared iGPU —
                # the Level Zero alloc fails and the SYCL backend abort()s
                # (SIGABRT), surfacing as a 500 after the session grows.
                contextWindow = 32768;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "gemma4:12b";
                name = "Gemma 4 12B";
                # This build emits a gemma4 thinking channel (RENDERER/PARSER
                # gemma4); with thinking on it deliberates for hundreds of
                # tokens before answering. pi must know it's a reasoning model
                # to parse/display the thinking channel correctly.
                reasoning = true;
                input = [
                  "text"
                  "image"
                ];
                # Match the local ollama server's OLLAMA_CONTEXT_LENGTH (32768,
                # set in hosts/coltrane/ollama.nix). pi only uses this to budget
                # prompt size; it is NOT sent as num_ctx over the /v1 endpoint,
                # so advertising 131072 here just lets pi overflow the real 32K
                # window the server actually serves (silent truncation).
                contextWindow = 32768;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
            ];
          };
          ollama-wobcom = {
            baseUrl = "http://ollama.service.wobcom.de:11434/v1";
            api = "openai-completions";
            apiKey = "ollama";
            compat = {
              supportsDeveloperRole = false;
              supportsReasoningEffort = false;
            };
            models = [
              {
                id = "gpt-oss:120b";
                name = "GPT-OSS 120B";
                reasoning = true;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "gemma4:31b";
                name = "Gemma 4 31B";
                # gemma4 family is a reasoning model (thinking capability
                # confirmed via /api/show); see gemma4:12b above.
                reasoning = true;
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "qwen3.5:latest";
                name = "Qwen 3.5";
                reasoning = true;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
                compat.thinkingFormat = "qwen-chat-template";
              }
              {
                id = "gemma3:27b";
                name = "Gemma 3 27B";
                reasoning = false;
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "deepseek-r1:32b";
                name = "DeepSeek R1 32B";
                reasoning = true;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "mistral-small:24b";
                name = "Mistral Small 24B";
                reasoning = false;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "qwen2.5:14b-instruct";
                name = "Qwen 2.5 14B Instruct";
                reasoning = false;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "qwen2.5:7b-instruct";
                name = "Qwen 2.5 7B Instruct";
                reasoning = false;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "qwen3-coder:latest";
                name = "Qwen 3 Coder";
                reasoning = false;
                input = [ "text" ];
                contextWindow = 262144;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "gemma4:26b";
                name = "Gemma 4 26B";
                # gemma4 family is a reasoning model (thinking capability
                # confirmed via /api/show); see gemma4:12b above.
                reasoning = true;
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "bge-m3:latest";
                name = "bge-m3";
                reasoning = false;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
              {
                id = "nomic-embed-text:latest";
                name = "nomic-embed-text";
                reasoning = false;
                input = [ "text" ];
                contextWindow = 131072;
                maxTokens = 8192;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
            ];
          };
        };
      };
    };
    settings = lib.mkOption {
      type = lib.types.attrs;
      description = "General agent settings";
      default = {
        defaultProvider = "ollama-wobcom";
        defaultModel = "qwen3-coder:latest";
        theme = "dracula";
        skills = [ "/home/marv/.claude/skills" ];
      };
    };
    mcpServers = lib.mkOption {
      type = lib.types.attrs;
      description = "MCP server configurations";
      default = { };
    };
  };

  config =
    let
      cfg = config.xsfx.codingAgent;

      # Resolve each MCP server against the registry: the registry is the
      # source of truth for `bin` and `command`; a host only supplies args,
      # env. Any `*_FILE` env var triggers the secret wrapper automatically
      # (the sops-nix `_FILE` convention); plain env vars pass through.
      resolveServer =
        name: server:
        let
          serverDef =
            registry.mcpRegistry."${name}" or {
              bin = null;
              command = name;
            };
          bin = server.bin or serverDef.bin;
          command = server.command or serverDef.command;
          env = server.env or { };
          needsWrap = lib.any (k: lib.hasSuffix "_FILE" k) (lib.attrNames env);
        in
        {
          inherit command;
          bin =
            if needsWrap && bin != null then wrapperLib.mkSecretWrapper { inherit bin command env; } else bin;
        };

      # Resolve each server once; both the package list and the mcp.json
      # manifest derive from this so the (potentially expensive) wrapper
      # derivation is built a single time per server.
      resolved = lib.mapAttrs (
        name: server:
        resolveServer name server
        // {
          args = server.args or [ ];
          env = server.env or { };
        }
      ) cfg.mcpServers;

      mcpPackages = lib.mapAttrs (_: r: r.bin) resolved;

      # The final bundled package
      codingAgentWithExtensions = pkgs.symlinkJoin {
        name = "coding-agent-with-extensions";
        paths = [
          pkgs.pi-coding-agent
          pkgs.agent-browser
          buildExts.permissionSystem
          buildExts.mcpAdapter
          buildExts.browserTools
        ]
        ++ lib.filter (x: x != null) (lib.attrValues mcpPackages);
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/pi \
            --add-flags "--extension ${buildExts.permissionSystem}/lib/pi-permission-system/src/index.ts" \
            --add-flags "--extension ${buildExts.mcpAdapter}/index.ts" \
            --add-flags "--extension ${buildExts.browserTools}/extensions/browser-tools/index.ts"
        '';
      };

      # Lean local pi for offline use. The normal pi loads ~277 skills +
      # CLAUDE.md (~33k tokens); on a small local model on the Arc iGPU that is
      # minutes of prompt processing per turn and pi times out. This skips
      # skills/context/thinking and targets a small non-reasoning coder model
      # that fully fits the iGPU, so it answers in seconds with no internet.
      # Offline agent on the local ollama. qwen3-coder:30b is the only Qwen3
      # coder (a 30B-A3B MoE, ~3.3B active) that actually drives pi's agentic
      # tool loop reliably - smaller coders (qwen2.5-coder:7b) emit raw text-JSON
      # tool calls instead of real invocations. Slow on the Arc iGPU but
      # functional, which is the offline tradeoff we want. Skills are already
      # globally curated to a lean daily set (see skills.nix, ~1k tokens), so we
      # inherit it instead of stripping - the git/go skills stay available.
      piOffline = pkgs.writeShellScriptBin "pi-offline" ''
        exec ${codingAgentWithExtensions}/bin/pi \
          --provider ollama-local --model qwen3-coder:30b \
          --offline "$@"
      '';
    in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = options ? home-manager;
          message = ''
            xsfx.codingAgent requires home-manager.nixosModules.home-manager to be
            imported on this host (it writes the agent config under the user's home
            via home-manager.users.${cfg.user}.home.file).
          '';
        }
      ];

      environment.systemPackages = [
        codingAgentWithExtensions
        piOffline
      ];

      home-manager.users.${cfg.user}.home.file = {
        ".pi/agent/models.json" = {
          text = builtins.toJSON cfg.models;
          force = true;
        };
        ".pi/agent/themes/theme.json" = {
          text = builtins.toJSON cfg.theme;
          force = true;
        };
        ".pi/agent/settings.json" = {
          text = builtins.toJSON cfg.settings;
          force = true;
        };
        ".pi/agent/mcp.json" = {
          text = builtins.toJSON {
            mcpServers = lib.mapAttrs (_: r: {
              inherit (r) command args env;
            }) resolved;
          };
          force = true;
        };
      };
    };
}
