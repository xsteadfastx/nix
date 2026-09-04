{
  lib,
  stdenv,
  fetchurl,
  glibc,
  mesa,
  libGL,
  SDL2,
  libx11,
  libxext,
  libxrandr,
  libxcursor,
  libxi,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "lilium-voyager";
  version = "1.40";

  # Engine only. The proprietary Elite Force data (baseEF/*.pk3) is NOT in the
  # release tarball; the user provides it in ~/.local/share/lilium-voyager/baseEF
  # (the engine's default search path), same model as ioquake3 + Quake 3 data.
  src = fetchurl {
    url = "https://github.com/clover-moe/lilium-voyager/releases/download/v${version}/liliumvoyager-${version}-linux.tar.xz";
    hash = "sha256-cEQAGy431VP6vex0Rm0vlMfbprXu1xAOdKHwKtXKcl8=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    glibc
    mesa
    libGL
    SDL2
    libx11
    libxext
    libxrandr
    libxcursor
    libxi
  ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec $out/bin
    cp liliumvoyhm.x86_64 liliumvoyded.x86_64 $out/libexec/
    cp liliumvoyhm_renderer_opengl1_x86_64.so liliumvoyhm_renderer_opengl2_x86_64.so $out/libexec/

    local rpath="${
      lib.makeLibraryPath [
        mesa
        libGL
        SDL2
        libx11
        libxext
        libxrandr
        libxcursor
        libxi
      ]
    }"

    # The prebuilt binaries target generic Linux: their /lib64 interpreter is a
    # nix-ld stub and they dlopen libGL/libEGL/libX11 at runtime. Point the
    # interpreter at the real glibc loader and bake the lib paths into the rpath.
    for b in $out/libexec/liliumvoyhm.x86_64 $out/libexec/liliumvoyded.x86_64; do
      patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 \
        --set-rpath "$out/libexec:$rpath" "$b"
    done
    for r in $out/libexec/liliumvoyhm_renderer_*.so; do
      patchelf --set-rpath "$rpath" "$r"
    done

    # The engine dlopens the renderer from the current dir, so chdir to libexec.
    makeWrapper $out/libexec/liliumvoyhm.x86_64 $out/bin/lilium-voyager \
      --chdir $out/libexec \
      --set LD_LIBRARY_PATH "$rpath"
    makeWrapper $out/libexec/liliumvoyded.x86_64 $out/bin/lilium-voyager-server \
      --chdir $out/libexec \
      --set LD_LIBRARY_PATH "$rpath"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Engine replacement for Star Trek Voyager: Elite Force Holomatch";
    homepage = "https://clover.moe/lilium-voyager";
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ marv ];
  };
}
