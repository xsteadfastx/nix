{ pkgs, pkgsUnstable, ... }:
let
  crushConfig = builtins.toJSON {
    providers = {
      ollama-local = {
        id = "ollama-local";
        name = "Ollama (local)";
        base_url = "http://127.0.0.1:11434/v1";
        type = "openai-compat";
        api_key = "ollama";
        models = [
          {
            id = "qwen3.5";
            name = "Qwen 3.5 9B";
            context_window = 65536;
            default_max_tokens = 8192;
          }
          {
            id = "glm-4.7-flash";
            name = "GLM 4.7 Flash";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "qwen2.5-coder:14b";
            name = "Qwen 2.5 Coder 14B";
            context_window = 131072;
            default_max_tokens = 8192;
          }
        ];
      };
      ollama-wobcom = {
        id = "ollama-wobcom";
        name = "Ollama (wobcom)";
        base_url = "http://ollama.service.wobcom.de:11434/v1";
        type = "openai-compat";
        api_key = "ollama";
        models = [
          {
            id = "gpt-oss:120b";
            name = "GPT-OSS 120B";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "gemma4:31b";
            name = "Gemma 4 31B";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "qwen3.5:latest";
            name = "Qwen 3.5";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "gemma3:27b";
            name = "Gemma 3 27B";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "deepseek-r1:32b";
            name = "DeepSeek R1 32B";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "mistral-small:24b";
            name = "Mistral Small 24B";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "qwen2.5:14b-instruct";
            name = "Qwen 2.5 14B Instruct";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "qwen2.5:7b-instruct";
            name = "Qwen 2.5 7B Instruct";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "bge-m3:latest";
            name = "BGE-M3 Embeddings";
            context_window = 8192;
            default_max_tokens = 2048;
          }
          {
            id = "nomic-embed-text:latest";
            name = "Nomic Embed Text";
            context_window = 8192;
            default_max_tokens = 2048;
          }
        ];
      };
    };
    lsp = {
      go = {
        command = "gopls";
        filetypes = [
          "go"
          "gomod"
          "gowork"
          "gotmpl"
        ];
        root_markers = [
          "go.work"
          "go.mod"
          ".git"
        ];
      };
      nix = {
        command = "nil";
        filetypes = [ "nix" ];
        root_markers = [
          "flake.nix"
          ".git"
        ];
      };
      json = {
        command = "vscode-json-language-server";
        args = [ "--stdio" ];
        filetypes = [
          "json"
          "jsonc"
        ];
        root_markers = [ ".git" ];
      };
    };
    options = {
      context_paths = [ "/etc/nixos/configuration.nix" ];
      tui.compact_mode = true;
      debug = false;
    };
  };
  crushImg = pkgs.writeShellScriptBin "crush-img" ''
    OUT="/run/user/$(id -u)/crush_clipboard.png"
    TMP_OUT="/tmp/crush_clipboard_raw.png"
    if ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png -o > "$TMP_OUT" 2>/dev/null; then
      # Try to get it under 200KB
      ${pkgs.imagemagick}/bin/magick "$TMP_OUT" -strip -resize 50% "$OUT"
      
      while [ $(stat -c%s "$OUT") -gt 204800 ]; do
        ${pkgs.imagemagick}/bin/magick "$OUT" -resize 75% "$OUT"
        if [ $(stat -c%s "$OUT") -lt 10000 ]; then break; fi # Avoid infinite loop for tiny images
      done
      
      if [ $(stat -c%s "$OUT") -lt 204800 ]; then
        echo "Image captured and resized to fit limit: $OUT"
      else
        echo "Image captured but still too large: $OUT"
      fi
    else
      rm -f "$TMP_OUT"
      echo "Error: No image found in clipboard" >&2
      exit 1
    fi
  '';

  crushLatest = pkgs.buildGoModule (finalAttrs: {
    pname = "crush";
    version = "0.79.1";

    src = pkgs.fetchFromGitHub {
      owner = "charmbracelet";
      repo = "crush";
      tag = "v${finalAttrs.version}";
      hash = "sha256-S0e4mU7+PpMutz5CMs/hxoQHzuvcP6h/QY/jYQK27qw=";
    };

    vendorHash = "sha256-a+4k+fjqdWsAUv0ilagd46pYwFaSd1+mJ25Vr47Lsys=";

    checkFlags =
      let
        skippedTests = [
          "TestCoderAgent"
          "TestOpenAIClientStreamChoices"
          "TestGrepWithIgnoreFiles"
          "TestSearchImplementations"
          "TestDispatch_BinaryPassthroughExecutes"
        ];
      in
      [ "-skip=^${builtins.concatStringsSep "$|^" skippedTests}$" ];

    ldflags = [
      "-s"
      "-X=github.com/charmbracelet/crush/internal/version.Version=${finalAttrs.version}"
    ];
  });

  crushWithTools = pkgsUnstable.symlinkJoin {
    name = "crush-with-tools";
    paths = [
      crushLatest
    ];
    nativeBuildInputs = [ pkgsUnstable.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/crush \
        --prefix PATH :${
          pkgsUnstable.lib.makeBinPath [
            pkgsUnstable.gopls
            pkgsUnstable.nil
            pkgs.vscode-langservers-extracted
            crushImg
          ]
        }
    '';
  };
in
{
  environment.systemPackages = [
    crushWithTools
    crushImg
  ];

  home-manager.users.marv.xdg.configFile."crush/crush.json" = {
    text = crushConfig;
    force = true;
  };
}
