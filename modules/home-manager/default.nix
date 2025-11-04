{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  pkgsUnstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
    overlays = [
      inputs.firefox-addons.overlays.default
      inputs.self.overlays.default
    ];
  };
in
{
  options.xsfx.kodi = lib.mkEnableOption "enable kodi";
  options.xsfx.neovim = lib.mkEnableOption "enable neovim";
  options.xsfx.work = lib.mkEnableOption "enable work";
  options.xsfx.x11 = lib.mkEnableOption "enable x11";

  config = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = false; # Put the stuff to .nix-profile
    home-manager.extraSpecialArgs = { inherit inputs pkgsUnstable; };
  };
}
