{
  lib,
  runCommand,
  nerd-fonts,
  python3,
}:

# nixpkgs' pre-patched nerd-fonts.lilex with the slashed zero baked in as the
# default glyph. Lilex's default zero is dotted; the OpenType `zero` feature
# swaps in the slashed `zero.alt01` (`cv04` swaps in the plain `zero.alt02`).
# Copying `zero.alt01`'s outline over `zero` makes it slashed everywhere, with
# no fontconfig rule or per-app feature setting. No font-patcher run: the
# nerd-fonts build already carries every glyph set.
runCommand "lilex-nerdfont-zero-${nerd-fonts.lilex.version}"
  {
    nativeBuildInputs = [ (python3.withPackages (ps: [ ps.fonttools ])) ];
    meta = {
      description = "Lilex Nerd Font with a slashed zero as the default glyph";
      homepage = "https://github.com/mishamyrt/Lilex";
      license = lib.licenses.ofl;
      platforms = lib.platforms.all;
    };
  }
  ''
    cp -r --no-preserve=mode ${nerd-fonts.lilex} $out
    python3 - $out/share/fonts/truetype/NerdFonts/Lilex/*.ttf <<'EOF'
    import sys
    from fontTools.ttLib import TTFont
    for path in sys.argv[1:]:
        f = TTFont(path)
        # a renamed alternate upstream must fail the build, not ship a dotted zero
        assert "zero.alt01" in f["glyf"], f"{path}: no zero.alt01"
        f["glyf"]["zero"] = f["glyf"]["zero.alt01"]
        f["hmtx"]["zero"] = f["hmtx"]["zero.alt01"]
        f.save(path)
    EOF
  ''
