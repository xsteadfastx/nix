{
  inputs,
  lib,
  ...
}:
{
  options.features.games = lib.mkEnableOption "enable games";
  options.features.kodi = lib.mkEnableOption "enable kodi";
  options.features.neovim = lib.mkEnableOption "enable neovim";
  options.features.work = lib.mkEnableOption "enable work";
  options.features.x11 = lib.mkEnableOption "enable x11";

  config = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = false; # Put the stuff to .nix-profile
    home-manager.extraSpecialArgs = { inherit inputs; };
  };
}
