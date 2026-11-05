{
  fetchurl,
  runCommand,
  unzip,
}:

# DeDRM calibre plugins, taken from the release asset rather than built here.
#
# Why this fork: Apprentice Harper's original is dead, noDRM took over in 2021
# but has been frozen since 2024-11-10 (latest tags v10.0.3 stable / v10.0.9
# beta), and the work that keeps up with Amazon now happens in Satsuoni's fork
# (Kindle MSIX installs, the newer Kindle key store, KFX validation; a release
# every few weeks). Its release notes call the builds experimental, so treat
# this as a pin to bump, not a "stable" tag.
#
# The release asset carries Windows-only extras (KFXKeyExtractor.exe,
# kindledecr_*, Frida scripts) next to the two plugin zips; only the zips are
# extracted.
runCommand "calibre-dedrm-plugin"
  {
    src = fetchurl {
      url = "https://github.com/Satsuoni/DeDRM_tools/releases/download/v10.0.34/DeDRM_tools.zip";
      hash = "sha256-+XQxNBSQeKBz3i0p2nUP11NiINtesm0SznWNUv3qFOE=";
    };
    nativeBuildInputs = [ unzip ];
  }
  ''
    mkdir -p "$out"
    unzip -q -j "$src" DeDRM_plugin.zip Obok_plugin.zip -d "$out"
  ''
