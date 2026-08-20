{ config, ... }:
{
  codingAgent.enable = true;

  # marv's model providers. Kept in the host config (not the module) because
  # they are personal/hardware-specific.
  codingAgent.models = {
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
            # Small non-reasoning coder that fully fits the Arc iGPU.
            # Native context is 32768, matching the local ollama server.
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
          {
            # deepseek-v4-flash:0731-cloud — 304B FP8, served via the local
            # ollama but inference on a cloud backend (no iGPU cap, so the
            # full 1M context is advertised). thinking capability -> pi must
            # parse the reasoning channel.
            id = "deepseek-v4-flash:0731-cloud";
            name = "DeepSeek V4 Flash";
            reasoning = true;
            input = [ "text" ];
            contextWindow = 1048576; # /api/show
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
        # contextWindow values come from ollama /api/tags
        # (details.context_length). For models that don't report one
        # (gemma4:26b/31b, gemma3:27b) the family native is used:
        # gemma4 = 262144 (confirmed via gemma4:12b), gemma3 = 131072.
        # maxTokens is tiered by context: 32K ctx -> 8192 out,
        # 131K ctx -> 16384 out, 262K ctx -> 32768 out. Embedding
        # models keep 8192 (output cap irrelevant for embeddings).
        models = [
          {
            id = "qwen3.8:27b";
            name = "Qwen 3.8 27B";
            # qwen35 family (27.3B Q4_K_M), same thinking + vision +
            # tool-use capabilities as qwen3.6:35b but smaller.
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 262144; # /api/tags
            maxTokens = 32768;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
            compat.thinkingFormat = "qwen-chat-template";
          }
          {
            id = "muse-glimmer:30b";
            name = "Muse Glimmer 30B";
            # 27.9B Q4_K_M, muse-glimmer family. 131K native context;
            # thinking + vision capabilities per /api/tags.
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 131072; # /api/tags
            maxTokens = 32768;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
          }
          {
            id = "qwen3.6:35b";
            name = "Qwen 3.6 35B-A3B";
            # MoE: 35B total / 3B active params, qwen35moe family.
            # Vision + tools + thinking. Fast inference on wobcom (no iGPU cap).
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 262144; # /api/tags
            maxTokens = 32768;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
            compat.thinkingFormat = "qwen-chat-template";
          }
          {
            id = "qwen3.6:latest";
            name = "Qwen 3.6 36B";
            # qwen35moe, 36B Q4_K_M. Vision + tools + thinking.
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 262144; # /api/tags
            maxTokens = 32768;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
            compat.thinkingFormat = "qwen-chat-template";
          }
          {
            id = "gemma4:31b";
            name = "Gemma 4 31B";
            # gemma4 family is a reasoning model (thinking capability
            # confirmed via /api/show); see gemma4:12b in ollama-local.
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 262144; # gemma4 native (/api/tags on 12b)
            maxTokens = 32768;
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
            # confirmed via /api/show); see gemma4:12b in ollama-local.
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 262144; # gemma4 native (/api/tags on 12b)
            maxTokens = 32768;
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
            # gemma4 reasoning model with vision. Same build as the
            # ollama-local entry but served from wobcom (no iGPU cap,
            # so full 262K context advertised).
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 262144; # /api/tags
            maxTokens = 32768;
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
            contextWindow = 262144; # /api/tags
            maxTokens = 32768;
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
            # Same digest as qwen3-coder:latest; explicit tag alias.
            reasoning = false;
            input = [ "text" ];
            contextWindow = 262144; # /api/tags
            maxTokens = 32768;
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
            # qwen35, 9.7B. /api/tags reports vision capability.
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 262144; # /api/tags
            maxTokens = 32768;
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
            contextWindow = 131072; # gemma3 native
            maxTokens = 16384;
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
            contextWindow = 32768; # /api/tags
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
            contextWindow = 32768; # /api/tags
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
            contextWindow = 32768; # /api/tags
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
            # Embedding-only model (capability: embedding); kept for
            # tooling that may request it, not a chat/completion model.
            reasoning = false;
            input = [ "text" ];
            contextWindow = 8192; # /api/tags
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
            # Embedding-only model (capability: embedding).
            reasoning = false;
            input = [ "text" ];
            contextWindow = 2048; # /api/tags
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
