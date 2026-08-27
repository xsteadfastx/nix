{
  lib,
  fetchurl,
  stdenv,
  makeWrapper,
  trippy,
}:

# Trippy (trip) wrapped with a bundled GeoLite2-City mmdb and a Dracula TUI
# theme. Self-contained: binary + geoip data + config live in one store path,
# so `trip` just works with geoip + theme on any host/user. CLI flags still
# override the baked-in config per invocation.
#
# ponytail: the mmdb release is re-published roughly monthly; we pin to a tag
# (snapshot). Re-pin url/sha256 (and `version`) when geoip data freshness
# matters.

stdenv.mkDerivation rec {
  pname = "trippy-dracula";
  version = "2026.08.25";

  nativeBuildInputs = [ makeWrapper ];

  geoip = fetchurl {
    url = "https://github.com/P3TERX/GeoLite.mmdb/releases/download/${version}/GeoLite2-City.mmdb";
    sha256 = "b481e34bdfbeb937434d09b47d89622c36051560c5f64853b54e081678c7df74";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/trippy $out/bin
    cp ${geoip} $out/share/trippy/GeoLite2-City.mmdb
    cat > $out/share/trippy/trippy.toml <<EOF
    [tui]
    geoip-mmdb-file = "$out/share/trippy/GeoLite2-City.mmdb"
    tui-geoip-mode = "short"

    [theme-colors]
    bg-color = "282a36"
    border-color = "6272a4"
    text-color = "f8f8f2"
    tab-text-color = "bd93f9"
    hops-table-header-bg-color = "bd93f9"
    hops-table-header-text-color = "282a36"
    hops-table-row-active-text-color = "f8f8f2"
    hops-table-row-inactive-text-color = "6272a4"
    hops-chart-selected-color = "50fa7b"
    hops-chart-unselected-color = "6272a4"
    hops-chart-axis-color = "44475a"
    frequency-chart-bar-color = "50fa7b"
    frequency-chart-text-color = "6272a4"
    flows-chart-bar-selected-color = "bd93f9"
    flows-chart-bar-unselected-color = "44475a"
    flows-chart-text-current-color = "ff79c6"
    flows-chart-text-non-current-color = "f8f8f2"
    samples-chart-color = "f1fa8c"
    samples-chart-lost-color = "ff5555"
    help-dialog-bg-color = "44475a"
    help-dialog-text-color = "f8f8f2"
    settings-dialog-bg-color = "44475a"
    settings-tab-text-color = "50fa7b"
    settings-table-header-text-color = "282a36"
    settings-table-header-bg-color = "bd93f9"
    settings-table-row-text-color = "f8f8f2"
    map-world-color = "6272a4"
    map-radius-color = "f1fa8c"
    map-selected-color = "50fa7b"
    map-info-panel-border-color = "6272a4"
    map-info-panel-bg-color = "282a36"
    map-info-panel-text-color = "f8f8f2"
    info-bar-bg-color = "bd93f9"
    info-bar-text-color = "282a36"
    EOF
    makeWrapper ${trippy}/bin/trip $out/bin/trip \
      --add-flags "--config-file $out/share/trippy/trippy.toml"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Trippy (trip) with a bundled GeoLite2-City mmdb and Dracula theme";
    homepage = "https://trippy.rs";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
