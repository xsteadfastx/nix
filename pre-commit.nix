{
  nixfmt,
  prek,
  trufflehog,
  ...
}:
{
  package = prek;
  excludes = [
    "flake.lock"
    "hosts/.+/secrets.yaml"
    "home-manager/modules/tmux/.tmux-dracula/.+$"
    "home-manager/modules/gtk/Dracula.+"
  ];

  hooks = {
    pre-commit-hook-ensure-sops.enable = true;

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
      ];
    };

    nixfmt = {
      enable = true;
      package = nixfmt;
    };

    typos = {
      enable = true;
      excludes = [
        "home-manager/modules/aerc/aerc.conf"
        "home-manager/modules/i3/config"
      ];
    };

    trufflehog = {
      enable = true;
      package = trufflehog;
    };

    statix.enable = true;
  };
}
