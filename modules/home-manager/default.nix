{
  inputs,
  lib,
  ...
}:
{
  # Per-host capability switches: a host opts into the subsystems it runs, so a
  # future machine can take a subset -- and features.wobcom stays off anywhere
  # that is not the work machine. Host-scoped, not per-user.
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

      # Adopting a dotfile Home Manager did not write before (the first one was
      # ~/.profile and ~/.bashrc, when bash moved into home-manager/modules/bash.nix)
      # aborts the whole activation with "Existing file … would be clobbered" and
      # exit code 4. With a backup extension HM moves the old file aside to
      # <file>.backup and continues, which is what "take over this dotfile"
      # should mean -- the alternative is `force = true` per file, which silently
      # deletes the old content.
      backupFileExtension = "backup";
    };
  };
}
