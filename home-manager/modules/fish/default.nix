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

  # fish expands XDG_DATA_DIRS into fish_complete_path itself (also on
  # mid-session changes, e.g. direnv). Scripts that mutate
  # fish_complete_path at runtime make fish wipe loaded completions
  # (e.g. git) with no reload, so never add one here.

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
