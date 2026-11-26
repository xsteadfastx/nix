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
  # Combine the checked-in fonts with the JetBrains Mono Nerd Font build into
  # one directory, so there's a single home.file entry (no nested symlink that
  # the recursive parent can clobber).
  home.file.".local/share/fonts" = {
    source = pkgs.runCommand "fonts" { } ''
      mkdir -p $out/NerdFonts
      cp -r ${./fonts}/* $out/
      ln -s ${pkgs.jetbrains-mono-nerd}/share/fonts/truetype/NerdFonts/JetBrainsMono $out/NerdFonts/JetBrainsMono
    '';
    # The old config installed this as a real dir of symlinks; replace it.
    force = true;
  };

  # fontconfig decides whether a directory changed by its mtime, and everything
  # in /nix/store has mtime 1970 -- so replacing the font set behind
  # ~/.local/share/fonts leaves the *old* entries (dead store paths) in
  # ~/.cache/fontconfig. Pango then picks a file that no longer exists and every
  # glyph renders as tofu (2026-11-26: switching to JetBrains Mono, 128 dead
  # paths, "font_face status is: file not found"). Home Manager's own fc-cache
  # only covers the profile's share/fonts, not this dir, so refresh the user
  # cache here after the links are written. Apps already running keep the font
  # they resolved at startup either way (see CLAUDE.md).
  #
  # Both fontconfig versions the repo links get their own `-f` run: the cache
  # files in ~/.cache/fontconfig are keyed by fontconfig's cache format version,
  # so 2.17.1 (stable) refreshing its view left the 2.18.3 one (unstable: ghostty,
  # wayle) still pointing at dead paths.
  home.activation.fontsFcCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.fontconfig}/bin/fc-cache -f
    run ${pkgs.unstable.fontconfig}/bin/fc-cache -f
  '';

  # NOTE: the generic-family aliases (`monospace`, `mono`, `sans-serif`) live in
  # ../gtk/default.nix, next to `fonts.fontconfig.enable`. Do not add a second
  # `xdg.configFile."fontconfig/fonts.conf".text` anywhere: that option is a lines
  # value, so two definitions are *concatenated* into one file -- two XML
  # documents, which fontconfig rejects outright ("junk after document element")
  # and then ignores completely, leaving DejaVu Sans Mono in place. That is
  # exactly what happened here once.
}
