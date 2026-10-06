{
  inputs,
  lib,
  ...
}:
{
  options.features = {
    games = lib.mkEnableOption "enable games";
    kodi = lib.mkEnableOption "enable kodi";
    matrix = lib.mkEnableOption "enable matrix";
    meshcore = lib.mkEnableOption "enable meshcore";
    neovim = lib.mkEnableOption "enable neovim";
    wobcom = lib.mkEnableOption "wobcom work apps (1password, sandboxed Slack)";
    desktop = lib.mkEnableOption "the graphical desktop (sway/Wayland + GUI apps)";
  };

  config = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = false; # Put the stuff to .nix-profile
      extraSpecialArgs = { inherit inputs; };
    };
  };
}
