{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.programs.liliumVoyager.enable = lib.mkEnableOption "lilium-voyager";

  config = lib.mkIf config.programs.liliumVoyager.enable {
    home.packages = [
      pkgs.lilium-voyager
    ];
  };
}
