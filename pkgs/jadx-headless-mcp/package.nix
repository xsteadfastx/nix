{
  lib,
  stdenvNoCC,
  fetchurl,
}:
# Headless jadx MCP server, used by rea (hosts/coltrane/coding-agent.nix) for
# Android analysis. Upstream's prebuilt fat JAR; it runs on the caller's JDK.
#
# No passthru.updateScript on purpose: rea hardcodes the SHA-256 of the exact
# JAR it was verified with and rejects any other build, so this version follows
# rea, not upstream releases. When rea moves, take the version from the error
# rea's doctor prints (`rea doctor --provider jadx --json`).
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jadx-headless-mcp";
  version = "0.7.1";

  src = fetchurl {
    url = "https://github.com/1013503897/jadx-headless-mcp/releases/download/v${finalAttrs.version}/jadx-headless-mcp-${finalAttrs.version}-all.jar";
    hash = "sha256-bl6s9QC2QpK/tzxJeXwZWPbuRGRuQ+hoA5rn/rVz/3U=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm444 $src $out/share/java/jadx-headless-mcp.jar
    runHook postInstall
  '';

  meta = {
    description = "Headless MCP server for Android APK static analysis, built on jadx-core";
    homepage = "https://github.com/1013503897/jadx-headless-mcp";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    platforms = lib.platforms.all;
  };
})
