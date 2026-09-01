{
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  # Combine the checked-in fonts with the custom patched JetBrainsMono into one
  # directory, so there's a single home.file entry (no nested symlink that the
  # recursive parent can clobber).
  home.file.".local/share/fonts" = {
    source = pkgs.runCommand "fonts" { } ''
      mkdir -p $out
      cp -r ${./fonts}/* $out/
      ln -s ${pkgs.jetbrainsmono-nerdfont-zero}/share/fonts/truetype/NerdFonts $out/NerdFonts
    '';
    # The old config installed this as a real dir of symlinks; replace it.
    force = true;
  };
}
