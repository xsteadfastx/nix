{
  nixosConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;
in
lib.mkIf cfg.desktop {
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

  # NOTE: the generic-family aliases (`monospace`, `mono`, `sans-serif`) live in
  # ../gtk/default.nix, next to `fonts.fontconfig.enable`. Do not add a second
  # `xdg.configFile."fontconfig/fonts.conf".text` anywhere: that option is a lines
  # value, so two definitions are *concatenated* into one file -- two XML
  # documents, which fontconfig rejects outright ("junk after document element")
  # and then ignores completely, leaving DejaVu Sans Mono in place. That is
  # exactly what happened here once.
}
