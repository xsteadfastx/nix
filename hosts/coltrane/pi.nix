{ pkgsUnstable, ... }:
let
  # pi reads custom OpenAI-compatible providers from ~/.pi/agent/models.json.
  # This mirrors the providers/models defined in ./crush.nix so pi and crush
  # share the same local + remote Ollama backends.
  #
  # Ollama speaks the OpenAI Chat Completions API. It ignores the apiKey, but
  # pi requires the field, so any non-empty value works. Ollama does not
  # understand the `developer` role nor `reasoning_effort`, so disable both at
  # the provider level (thinking is toggled via Ollama's own `think` flag,
  # which pi enables when a model is marked `reasoning: true`).
  ollamaCompat = {
    supportsDeveloperRole = false;
    supportsReasoningEffort = false;
  };

  piModels = builtins.toJSON {
    providers = {
      ollama-local = {
        baseUrl = "http://127.0.0.1:11434/v1";
        api = "openai-completions";
        apiKey = "ollama";
        compat = ollamaCompat;
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
        ];
      };
      ollama-wobcom = {
        baseUrl = "http://ollama.service.wobcom.de:11434/v1";
        api = "openai-completions";
        apiKey = "ollama";
        compat = ollamaCompat;
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
        ];
      };
    };
  };
  # Dracula theme. pi ships only `dark`/`light`, so define the full palette as
  # a custom theme (all 51 required color tokens) using the official Dracula
  # colors. https://draculatheme.com/contribute#color-palette
  draculaTheme = builtins.toJSON {
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
      # Core UI
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
      # Backgrounds & content
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
      # Markdown
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
      # Tool diffs
      toolDiffAdded = "green";
      toolDiffRemoved = "red";
      toolDiffContext = "comment";
      # Syntax highlighting
      syntaxComment = "comment";
      syntaxKeyword = "pink";
      syntaxFunction = "green";
      syntaxVariable = "fg";
      syntaxString = "yellow";
      syntaxNumber = "purple";
      syntaxType = "cyan";
      syntaxOperator = "pink";
      syntaxPunctuation = "fg";
      # Thinking level borders (subtle -> prominent)
      thinkingOff = "comment";
      thinkingMinimal = "cyan";
      thinkingLow = "green";
      thinkingMedium = "yellow";
      thinkingHigh = "orange";
      thinkingXhigh = "pink";
      # Bash mode
      bashMode = "orange";
    };
    export = {
      pageBg = "#21222c";
      cardBg = "#282a36";
      infoBg = "#44475a";
    };
  };

  piSettings = builtins.toJSON {
    theme = "dracula";
  };
  piVersion = "0.80.2";
  piSrc = pkgsUnstable.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${piVersion}";
    hash = "sha256-aKtgPc3rwHEp856jP3N7nImph0CSG+gsWq9OVci3hmE=";
  };
  # buildNpmPackage bakes `npmDeps` from the original src at call time, so
  # overrideAttrs must replace `npmDeps` itself — setting only `npmDepsHash`
  # would keep fetching the previous version's package-lock and fail with a
  # lockfile mismatch.
  piLatest = pkgsUnstable.pi-coding-agent.overrideAttrs (_: {
    version = piVersion;
    src = piSrc;
    npmDeps = pkgsUnstable.fetchNpmDeps {
      src = piSrc;
      name = "pi-coding-agent-${piVersion}-npm-deps";
      hash = "sha256-1EGs8lX8XoAnRtS+pw4lBRm24U/vtVB2loVRmZyd4Z8=";
    };
  });
in
{
  environment.systemPackages = [ piLatest ];

  # Embedding-only models (bge-m3, nomic-embed-text) from the crush config are
  # intentionally omitted: pi is a chat/coding agent and cannot use embedding
  # models, so listing them would only clutter the /model picker.
  home-manager.users.marv.home.file = {
    ".pi/agent/models.json" = {
      text = piModels;
      force = true;
    };
    ".pi/agent/themes/dracula.json" = {
      text = draculaTheme;
      force = true;
    };
    ".pi/agent/settings.json" = {
      text = piSettings;
      force = true;
    };
  };
}
