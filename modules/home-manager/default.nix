{
  inputs,
  lib,
  ...
}:
{
  options.features.games = lib.mkEnableOption "enable games";
  options.features.kodi = lib.mkEnableOption "enable kodi";
  options.features.matrix = lib.mkEnableOption "enable matrix";
  options.features.meshcore = lib.mkEnableOption "enable meshcore";
  options.features.neovim = lib.mkEnableOption "enable neovim";
  options.features.wobcom = lib.mkEnableOption "wobcom work apps (1password, sandboxed Slack)";
  options.features.x11 = lib.mkEnableOption "enable x11";

  config = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = false; # Put the stuff to .nix-profile
    home-manager.extraSpecialArgs = { inherit inputs; };
  };
}
