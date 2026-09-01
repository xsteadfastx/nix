{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  fontforge,
  unzip,
  python3,
}:

# Patch our own JetBrains Mono with Nerd Fonts glyphs via the upstream
# font-patcher script (instead of using the pre-patched nerd-fonts.jetbrains-mono).
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jetbrainsmono-nerdfont-zero";
  version = "2.304";

  src = fetchurl {
    url = "https://github.com/JetBrains/JetBrainsMono/releases/download/v${finalAttrs.version}/JetBrainsMono-${finalAttrs.version}.zip";
    hash = "sha256-b2N2xu0pYOqKljzXOH7J124/YpElvDPR/c1+twEve78=";
  };

  nerdFontsSrc = fetchFromGitHub {
    owner = "ryanoasis";
    repo = "nerd-fonts";
    rev = "73e5da3b3353b78afcf32734281a18b5d3dc5c8f";
    hash = "sha256-CzKZXBAWqnn+OUDNkEdsYbRc3U2Bxv1nP/iaCZgbYEA=";
  };

  nativeBuildInputs = [
    fontforge
    unzip
    (python3.withPackages (ps: [ ps.fonttools ]))
  ];

  sourceRoot = ".";

  buildPhase = ''
    runHook preBuild
    unzip $src -d jbm
    mkdir -p $out/share/fonts/truetype/NerdFonts
    for f in jbm/fonts/ttf/*.ttf; do
      fontforge --lang=py -script $nerdFontsSrc/font-patcher "$f" \
        --outputdir $out/share/fonts/truetype/NerdFonts
      # Mono variant (single-width glyphs) for powerline/status bars.
      fontforge --lang=py -script $nerdFontsSrc/font-patcher "$f" --mono \
        --outputdir $out/share/fonts/truetype/NerdFonts
    done
    runHook postBuild
  '';

  # Bake the slashed zero as the default glyph: JetBrains Mono ships a dotted
  # zero with the `zero` OpenType feature swapping to the slashed `zero.zero`
  # alternate. Copy `zero.zero`'s glyph data into `zero` so the slashed zero is
  # on by default everywhere (no fontconfig rule needed). Uses fontTools, not
  # fontforge (whose `foreground` setter doesn't persist) and not pyftfeatfreeze
  # (which errors on the long "JetBrainsMono Nerd Font <Weight>" family names).
  postInstall = ''
        for f in $out/share/fonts/truetype/NerdFonts/*.ttf; do
          python3 -c "
    from fontTools.ttLib import TTFont
    f = TTFont('$f')
    glyf = f['glyf']
    if 'zero.zero' in glyf:
        glyf['zero'] = glyf['zero.zero']
    f.save('$f')
    "
        done
  '';

  meta = {
    description = "JetBrains Mono patched with Nerd Fonts glyphs (custom build)";
    homepage = "https://github.com/ryanoasis/nerd-fonts";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
})
