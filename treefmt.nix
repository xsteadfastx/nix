{ ... }:
{
  projectRootFile = "flake.nix";

  programs = {
    deadnix.enable = true;
    nixfmt.enable = true;
    shfmt.enable = true;
  };

  settings = {
    formatter = {
      shfmt = {
        excludes = [
          "home-manager/modules/tmux/.tmux-dracula/*"
        ];
      };
    };
  };
}
