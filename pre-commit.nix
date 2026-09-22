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
    "home-manager/secrets.yaml"
    "home-manager/modules/tmux/.tmux-dracula/.+$"
  ];

  hooks = {
    pre-commit-hook-ensure-sops = {
      enable = true;
      excludes = [
        "secrets/.+\\.xml"
        "secrets/.+\\.nix"
      ];
    };

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
      ];
      # The repo's own typos config, so both stages (pre-commit and commit-msg)
      # read the same file. Without this the pre-commit stage gets a generated
      # config and .typos.toml only applies to commit messages.
      settings.configPath = ".typos.toml";
    };

    trufflehog = {
      enable = true;
      package = trufflehog;
    };

    statix.enable = true;
  };
}
