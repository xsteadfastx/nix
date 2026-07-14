{
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.unstable.fish
    pkgs.unstable.starship
  ];

  xdg.configFile."fish" = {
    source = ./fish;
    recursive = true;
  };

  xdg.configFile."fish/functions/fzf_key_bindings.fish".source =
    "${pkgs.unstable.fzf}/share/fzf/key-bindings.fish";

  # syncs XDG_DATA_DIRS changes (e.g. from direnv) into fish_complete_path
  xdg.configFile."fish/conf.d/completion-sync.fish".source = "${
    pkgs.unstable.fetchFromGitHub {
      owner = "iynaix";
      repo = "fish-completion-sync";
      rev = "4f058ad2986727a5f510e757bc82cbbfca4596f0";
      hash = "sha256-kHpdCQdYcpvi9EFM/uZXv93mZqlk1zCi2DRhWaDyK5g=";
    }
  }/init.fish";

  xdg.configFile."starship.toml".text = ''
    [kubernetes]
    disabled = false

    [aws]
    symbol = " "

    [conda]
    symbol = " "

    [dart]
    symbol = " "

    [directory]
    read_only = " "

    [docker_context]
    symbol = " "

    [elixir]
    symbol = " "

    [elm]
    symbol = " "

    [git_branch]
    symbol = " "

    [golang]
    symbol = " "

    [hg_branch]
    symbol = " "

    [java]
    symbol = " "

    [julia]
    symbol = " "

    [memory_usage]
    symbol = " "

    [nim]
    symbol = " "

    [nix_shell]
    symbol = " "

    [nodejs]
    symbol = " "
    disabled = true

    [package]
    symbol = " "

    [perl]
    symbol = " "

    [php]
    symbol = " "

    [python]
    symbol = " "

    [ruby]
    symbol = " "

    [rust]
    symbol = " "

    [swift]
    symbol = "ﯣ "
  '';
}
