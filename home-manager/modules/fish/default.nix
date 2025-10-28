{ pkgsUnstable, ... }:
{
  home.packages = [
    pkgsUnstable.fish
    pkgsUnstable.starship
  ];

  xdg.configFile."fish" = {
    source = ./fish;
    recursive = true;
  };

  xdg.configFile."fish/functions/fzf_key_bindings.fish".source =
    "${pkgsUnstable.fzf}/share/fzf/key-bindings.fish";

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
