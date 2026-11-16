{
  lib,
  stdenv,
  fetchzip,
  fetchurl,
  nerd-font-patcher,
  python3,
}:

# Nerdwand Mono: upstream's Nerd Font build of Nordwand Mono (they don't ship
# it, it's a local `make build-nerd-font`), with two extras baked in:
#   - `0` is the font's own slashed zero (`zero_slashed`), not the plain `zero`;
#   - every optional ligature is on, including the `dlig` joining forms for
#     runs of =, -, _ and # that upstream disables by default.
# Both are explained in ./font.py.
stdenv.mkDerivation (finalAttrs: {
  pname = "nordwand-mono-nerd";
  version = "1.5.3";

  src = fetchzip {
    url = "https://github.com/tywr/Nordwand-Mono/releases/download/${finalAttrs.version}/NordwandMono-TTF.zip";
    hash = "sha256-6G/liK+lhWx3Qc3z2SQMyJHot0GPLzTB6R2J1TMGffg=";
    stripRoot = false;
  };

  fontLicense = fetchurl {
    url = "https://raw.githubusercontent.com/tywr/Nordwand-Mono/${finalAttrs.version}/LICENSE-FONT.txt";
    hash = "sha256-4OST7a5xStW7JDo0bz/UXs3ZSgBYQRgpfy0F4PYYfTg=";
  };

  nativeBuildInputs = [
    nerd-font-patcher
    (python3.withPackages (ps: [ ps.fonttools ]))
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    fonts=$out/share/fonts/truetype/NerdFonts/NordwandMono
    mkdir -p $fonts
    # font.py patches its inputs in place, so work on a copy, not the store.
    cp ${finalAttrs.src}/*.ttf .
    python3 ${./font.py} . $fonts
    install -m644 ${finalAttrs.fontLicense} $fonts/LICENSE-FONT.txt
    runHook postInstall
  '';

  meta = {
    description = "Nerdwand Mono: Nordwand Mono Nerd Font with a slashed zero and all ligatures enabled";
    homepage = "https://github.com/tywr/Nordwand-Mono";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
})
