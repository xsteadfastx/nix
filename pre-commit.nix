{
  nixfmt-rfc-style,
  trufflehog,
  ...
}:
{
  src = ./.;
  excludes = [
    "flake.lock"
    "hosts/.+/secrets.yaml"
  ];
  hooks = {
    check-yaml.enable = true;
    convco.enable = true;
    deadnix.enable = true;

    ripsecrets = {
      enable = true;
      excludes = [ ];
    };

    shellcheck = {
      enable = true;
      excludes = [
        ".envrc"
        "home-manager/modules/tmux/.tmux-dracula/.+$"
      ];
    };

    nixfmt-rfc-style = {
      enable = true;
      package = nixfmt-rfc-style;
    };

    typos = {
      enable = true;
      excludes = [
        "home-manager/modules/tmux/.tmux-dracula/.+$"
        "home-manager/modules/aerc/aerc.conf"
        "home-manager/modules/i3/config"
      ];
    };

    trufflehog = {
      enable = true;
      package = trufflehog;
    };
  };
}
