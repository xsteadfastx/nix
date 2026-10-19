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

  # niri's own UI text -- hotkey overlay, screenshot UI, exit dialog -- asks
  # fontconfig for the generic family `monospace` (literally, in its markup), and
  # fontconfig answers with DejaVu Sans Mono. Same for anything else that asks for
  # the generic name instead of a family. Preferring the Nerd Font here fixes the
  # lot in one place; apps that name their family explicitly (ghostty, waybar,
  # zellij) are unaffected, and DejaVu stays as the fallback for glyphs the Nerd
  # Font lacks.
  #
  # Verified with `fc-match monospace` against this exact file: DejaVu Sans Mono
  # without it, JetBrainsMono Nerd Font with it.
  xdg.configFile."fontconfig/fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <alias binding="same">
        <family>monospace</family>
        <prefer><family>JetBrainsMono Nerd Font</family></prefer>
      </alias>
    </fontconfig>
  '';
}
