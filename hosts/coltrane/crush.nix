{ pkgsUnstable, ... }:
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
            id = "glm-4.7-flash:latest";
            name = "GLM 4.7 Flash";
            context_window = 131072;
            default_max_tokens = 8192;
          }
          {
            id = "qwen3.5:latest";
            name = "Qwen 3.5";
            context_window = 65536;
            default_max_tokens = 8192;
          }
          {
            id = "qwen2.5:14b-instruct";
            name = "Qwen 2.5 14B Instruct";
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
            id = "deepseek-r1:32b";
            name = "DeepSeek R1 32B";
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
        ];
      };
    };
    lsp = {
      go.command = "gopls";
      nix.command = "nil";
    };
    options = {
      context_paths = [ "/etc/nixos/configuration.nix" ];
      tui.compact_mode = true;
      debug = false;
    };
  };
in
{
  environment.systemPackages = [ pkgsUnstable.crush ];

  home-manager.users.marv.xdg.configFile."crush/crush.json" = {
    text = crushConfig;
    force = true;
  };
}
