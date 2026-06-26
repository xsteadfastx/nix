{ pkgs, pkgsUnstable, ... }:
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

  # @gotgenes/pi-permission-system: a published permission-enforcement extension
  # that gates bash/edit/write tool calls. Vendored straight from the npm
  # registry rather than the gotgenes/pi-packages pnpm monorepo — it has only
  # two runtime deps and both are WASM-only at the code path pi uses, so we skip
  # pnpm entirely and assemble the package tree by hand.
  #
  # The published tarball ships raw TypeScript under src/ (pi loads src/index.ts
  # via its bundled jiti — no build step). web-tree-sitter and tree-sitter-bash
  # are placed in an adjacent node_modules so the extension's
  # createRequire(...).resolve("<dep>/<file>.wasm") calls succeed. tree-sitter-
  # bash's node-gyp native binding is never exercised (only its prebuilt .wasm
  # grammar is loaded through web-tree-sitter), so its build-time deps are
  # intentionally omitted.
  piPermissionSystem =
    let
      extTarball = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@gotgenes/pi-permission-system/-/pi-permission-system-16.0.2.tgz";
        hash = "sha256-oq6bmJwZ6vwcpABCJ2SU+RteAckcMbU+hiniOJHMh5U=";
      };
      webTreeSitter = pkgs.fetchurl {
        url = "https://registry.npmjs.org/web-tree-sitter/-/web-tree-sitter-0.26.9.tgz";
        hash = "sha256-qs2KtgWPwTLlMVJtclNHarxWsMZGN+IDewIJIFwUaRs=";
      };
      treeSitterBash = pkgs.fetchurl {
        url = "https://registry.npmjs.org/tree-sitter-bash/-/tree-sitter-bash-0.25.1.tgz";
        hash = "sha256-1LKBlQjql8uJU//34wSmENRDAHvTlcjwOhXemorkpvk=";
      };
    in
    pkgs.runCommand "pi-permission-system-16.0.2" { } ''
      dest=$out/lib/pi-permission-system
      mkdir -p $dest/node_modules/web-tree-sitter $dest/node_modules/tree-sitter-bash
      tar -xzf ${extTarball} -C $dest --strip-components=1
      tar -xzf ${webTreeSitter} -C $dest/node_modules/web-tree-sitter --strip-components=1
      tar -xzf ${treeSitterBash} -C $dest/node_modules/tree-sitter-bash --strip-components=1
    '';

  piMcpAdapter = pkgs.buildNpmPackage {
    pname = "pi-mcp-adapter";
    version = "2.8.0";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/pi-mcp-adapter/-/pi-mcp-adapter-2.8.0.tgz";
      hash = "sha256-kSjvMGShpuRb+ImdzY9PPbIAZahOTtA+SoOlPLTvg2w=";
    };
    sourceRoot = "package";
    postPatch = ''
      ${pkgs.jq}/bin/jq 'del(.devDependencies)' package.json > package.json.tmp
      mv package.json.tmp package.json
      cp ${./pi-mcp-adapter/package-lock.json} package-lock.json
    '';
    npmDepsHash = "sha256-Uy8+2R4YcQ8H9SWQiewJrR0Uj8OK16+YlnM4rErsSoE=";
    dontNpmBuild = true;
    makeCacheWritable = true;
    installPhase = ''
      mkdir -p $out
      cp -r . $out
    '';
  };

  # @dreki-gg/pi-browser-tools: keyless web search (DuckDuckGo HTML by default),
  # page fetch/extract, screenshots, and optional CDP browser control. Built with
  # buildNpmPackage from the package's published npm tarball.
  #
  # We use the npm tarball rather than fetchFromGitHub on purpose: upstream is a
  # bun monorepo, and unpacking the whole repo makes npm detect the workspace
  # root and refuse `npm ci` ("no lockfile" at the root). The published tarball
  # is just the package itself, so npm operates on it cleanly.
  #
  # Upstream ships no npm lockfile (bun) and nixpkgs has no bun fetcher, so we
  # pin a generated, prod-only package-lock.json (committed next to this module)
  # and inject it in postPatch — the documented pattern for upstreams without a
  # usable lock. buildNpmPackage forwards postPatch/sourceRoot into its internal
  # fetchNpmDeps, so the same lock drives both the dependency fetch and `npm ci`.
  #
  # devDependencies are stripped first (jq): they are lint/format tooling
  # (oxlint/oxfmt) that drags in ~38 cross-platform native binaries we never run.
  # pi loads the raw TS under extensions/browser-tools/ via jiti, so there is no
  # build step — dontNpmBuild + a copy-only install just need node_modules.
  piBrowserTools = pkgs.buildNpmPackage {
    pname = "pi-browser-tools";
    version = "0.6.0";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@dreki-gg/pi-browser-tools/-/pi-browser-tools-0.6.0.tgz";
      hash = "sha256-A3vZzkrBVMOq+Ox1E2BIH9AKjQk6tsSy8/Oj6IzAj7c=";
    };
    sourceRoot = "package";
    postPatch = ''
      ${pkgs.jq}/bin/jq 'del(.devDependencies)' package.json > package.json.tmp
      mv package.json.tmp package.json
      cp ${./pi-browser-tools/package-lock.json} package-lock.json
    '';
    npmDepsHash = "sha256-f+skxoAJTvQRORXHv6E4d7fjZWrL+513tjeuYOynuVc=";
    npmDepsFetcherVersion = 2;
    dontNpmBuild = true;
    makeCacheWritable = true;
    npmFlags = [ "--ignore-scripts" ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out
      runHook postInstall
    '';
  };

  piSettings = builtins.toJSON {
    defaultProvider = "ollama-wobcom";
    defaultModel = "gemma4:31b";
    theme = "dracula";
    # Reuse the Agent Skills bundle that claude.nix installs (~/.claude/skills).
    # pi loads each entry as a skill tree, exposing them as /skill:<name>.
    skills = [ "/home/marv/.claude/skills" ];
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

  # pi only loads extensions from ~/.pi/agent/extensions, .pi/extensions, paths
  # listed in settings.json, and `--extension` flags — never from its own
  # install tree. So bundle the extension by wrapping pi to pass it on every
  # invocation. CLI `--extension` paths load in "temporary" scope (never written
  # to settings.json), which is exactly right for a Nix-managed, immutable
  # extension. We point at the entry file directly (the package's
  # `pi.extensions` manifest target); it lives inside the package dir, so its
  # deps and `#src/*` subpath imports resolve against the adjacent node_modules.
  piWithExtensions = pkgsUnstable.symlinkJoin {
    name = "pi-with-extensions";
    paths = [ piLatest ];
    nativeBuildInputs = [ pkgsUnstable.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --add-flags "--extension ${piPermissionSystem}/lib/pi-permission-system/src/index.ts" \
        --add-flags "--extension ${piBrowserTools}/extensions/browser-tools/index.ts" \
        --add-flags "--extension ${piMcpAdapter}/src/index.ts"
    '';
  };
in
{
  environment.systemPackages = [ piWithExtensions ];

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
    ".pi/agent/mcp.json" = {
      text = builtins.toJSON {
        mcpServers = { };
      };
      force = true;
    };
  };
}
