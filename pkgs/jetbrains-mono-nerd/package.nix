{
  runCommand,
  nerd-fonts,
  python3,
}:

# nixpkgs' prebuilt JetBrainsMono Nerd Font, with JetBrains Mono's slashed zero
# baked in: upstream's `zero` is dotted and only swaps to the slashed `zero.zero`
# under the `zero` OpenType feature, which no app here enables. Copying the glyph
# over is font-level, so it shows up everywhere without a fontconfig rule.
#
# Only the plain "Nerd Font" set is installed, not its `Mono` (single-cell
# icons, too small next to status-bar text), `Propo` (proportional) or `NL`
# (no ligatures) siblings.
runCommand "jetbrains-mono-nerd-slashed-zero"
  {
    nativeBuildInputs = [ (python3.withPackages (ps: [ ps.fonttools ])) ];
  }
  ''
    fonts=$out/share/fonts/truetype/NerdFonts/JetBrainsMono
    mkdir -p $fonts
    cp ${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-*.ttf $fonts/
    # cp copies the store's read-only mode; fontTools rewrites them in place.
    chmod u+w $fonts/*.ttf
    python3 - "$fonts" <<'PY'
    import glob, sys
    from fontTools.ttLib import TTFont

    for path in glob.glob(sys.argv[1] + "/*.ttf"):
        font = TTFont(path)
        assert "zero.zero" in font["glyf"], f"{path}: no zero.zero to copy"
        font["glyf"]["zero"] = font["glyf"]["zero.zero"]
        font["hmtx"]["zero"] = font["hmtx"]["zero.zero"]
        font.save(path)
    PY
  ''
