{ inputs, ... }:
{
  imports = [
    ./modules
    inputs.sops-nix.homeManagerModules.sops
  ];

  home = {
    username = "marv";
    homeDirectory = "/home/marv";

    stateVersion = "24.05";

    sessionVariables = {
      # EDITOR = "emacs";
    };
  };

  programs = {
    # Let Home Manager install and manage itself.
    home-manager.enable = true;

    # Direnv
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
