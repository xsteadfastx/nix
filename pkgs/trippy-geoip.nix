{
  lib,
  # lib/palette.nix for a Catppuccin TUI theme; null = trippy's own colours.
  ctp ? null,
  stdenv,
  makeWrapper,
  trippy,
  dbip-city-lite,
}:

# Trippy (trip) wrapped with a bundled IP-to-city mmdb and, on hosts with
# Catppuccin, its TUI theme. Self-contained: binary + geoip data + config live
# in one store path, so `trip` just works on any host/user. CLI flags still
# override the baked-in config per invocation.
#
# trippy has no Catppuccin port, so its theme is generated from lib/palette.nix
# (`ctp`, passed by modules/base). Trippy wants bare hex, no '#'.
#
# The mmdb comes from nixpkgs' dbip-city-lite (same MaxMind MMDB format trip
# reads; IP-to-city granularity matching the old GeoLite2-City). Previously we
# pinned a P3TERX/GeoLite.mmdb release tag, but P3TERX prunes old releases
# (keeps only the two newest), so the pinned URL 404'd and CI failed on every
# republish. dbip-city-lite's version/hash are maintained upstream and refresh
# on `nix flake update`.

let
  hex = name: lib.removePrefix "#" (ctp.hex name);

  # trippy theme key -> Catppuccin colour.
  themeColors = {
    bg-color = "base";
    border-color = "overlay1";
    text-color = "text";
    tab-text-color = "mauve";
    hops-table-header-bg-color = "mauve";
    hops-table-header-text-color = "base";
    hops-table-row-active-text-color = "text";
    hops-table-row-inactive-text-color = "overlay1";
    hops-chart-selected-color = "green";
    hops-chart-unselected-color = "overlay1";
    hops-chart-axis-color = "surface1";
    frequency-chart-bar-color = "green";
    frequency-chart-text-color = "overlay1";
    flows-chart-bar-selected-color = "mauve";
    flows-chart-bar-unselected-color = "surface1";
    flows-chart-text-current-color = "pink";
    flows-chart-text-non-current-color = "text";
    samples-chart-color = "yellow";
    samples-chart-lost-color = "red";
    help-dialog-bg-color = "surface1";
    help-dialog-text-color = "text";
    settings-dialog-bg-color = "surface1";
    settings-tab-text-color = "green";
    settings-table-header-text-color = "base";
    settings-table-header-bg-color = "mauve";
    settings-table-row-text-color = "text";
    map-world-color = "overlay1";
    map-radius-color = "yellow";
    map-selected-color = "green";
    map-info-panel-border-color = "overlay1";
    map-info-panel-bg-color = "base";
    map-info-panel-text-color = "text";
    info-bar-bg-color = "mauve";
    info-bar-text-color = "base";
  };

  theme = lib.optionalString (ctp != null) (
    "[theme-colors]\n"
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: color: ''${key} = "${hex color}"'') themeColors
    )
  );
in
stdenv.mkDerivation {
  pname = "trippy-geoip";
  inherit (dbip-city-lite) version;

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/trippy $out/bin
    cp ${dbip-city-lite.passthru.mmdb} $out/share/trippy/GeoLite2-City.mmdb
    cat > $out/share/trippy/trippy.toml <<EOF
    [tui]
    geoip-mmdb-file = "$out/share/trippy/GeoLite2-City.mmdb"
    tui-geoip-mode = "short"

    ${theme}
    EOF
    makeWrapper ${trippy}/bin/trip $out/bin/trip \
      --add-flags "--config-file $out/share/trippy/trippy.toml"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Trippy (trip) with a bundled IP-to-city mmdb (and a Catppuccin theme)";
    homepage = "https://trippy.rs";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
