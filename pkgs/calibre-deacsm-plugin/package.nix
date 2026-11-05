{
  fetchFromGitHub,
  fetchurl,
  runCommand,
  python3,
  zip,
}:

# ACSM Input ("DeACSM") calibre plugin: fulfills Adobe-DRM .acsm files into
# EPUB/PDF without Adobe Digital Editions, so DeDRM can strip the ADEPT layer.
#
# Built from master, not from a release: the newest release is v0.0.16 (2022),
# which predates both Adobe's 2026-06-23 migration from Adobe ID to ByteBooks ID
# (Wipro) and the 2024 TLS fixes that Thalia's Cloudflare-fronted fulfillment
# server needs.
#
# Two upstream build steps are skipped deliberately:
#   * keyextract/ compiles Windows .exe key decryptors with mingw. They are only
#     used to read ADE's keys on Windows; the base64 slots in
#     keyextractDecryptor.py are then left as inert placeholders.
#   * NixOS needs no source patch for libcrypto: the plugin already honours
#     ACSM_LIBCRYPTO / ACSM_LIBSSL (desktop.nix sets them).
let
  src = fetchFromGitHub {
    owner = "Leseratte10";
    repo = "acsm-calibre-plugin";
    rev = "4eff3ee35ac760ccad063639401b303b7207aa9c";
    hash = "sha256-vHWPxwF4UlSzrEkfC6YmQFNBUJNifZ0vzynzN68UPh0=";
  };

  # Prebuilt module zips from the repo's `config` release, as upstream's
  # package_modules.sh fetches them: oscrypto is a fork with OpenSSL 3 support.
  asn1crypto = fetchurl {
    url = "https://github.com/Leseratte10/acsm-calibre-plugin/releases/download/config/asn1crypto_1.5.1.zip";
    hash = "sha256-f0Wtf5qLAtuPqQ80uOfWtV4grf5CChRL3fcjkMSmEFA=";
  };
  oscrypto = fetchurl {
    url = "https://github.com/Leseratte10/acsm-calibre-plugin/releases/download/config/oscrypto_1.3.0_fork_2023-12-19.zip";
    hash = "sha256-D872/kQemxB2D7yUSuCIreAMGJOc9V7PtVommZPlwxc=";
  };

  # The plugin only re-extracts the bundled module zips when this id changes, so
  # it changes whenever they do.
  moduleId = "asn1crypto-f0Wtf5qLAtuPqQ80uOfWtV4grf5CChRL3fcjkMSmEFA-oscrypto-D872/kQemxB2D7yUSuCIreAMGJOc9V7PtVommZPlwxc=";
in
runCommand "calibre-deacsm-plugin"
  {
    inherit src asn1crypto oscrypto;
    nativeBuildInputs = [
      python3
      zip
    ];
  }
  ''
    cp -r --no-preserve=mode ${src}/calibre-plugin plugin
    cp ${asn1crypto} plugin/asn1crypto.zip
    cp ${oscrypto} plugin/oscrypto.zip
    cd plugin

    # Upstream's bundle_calibre_plugin.sh splices __calibre_compat_code.py into
    # every module that carries the marker; without it the plugin does not work
    # on calibre's Python.
    python3 - <<'PY'
    import pathlib

    compat = pathlib.Path("__calibre_compat_code.py").read_text()
    for path in pathlib.Path(".").rglob("*.py"):
        source = path.read_text()
        if "#@@CALIBRE_COMPAT_CODE@@" in source:
            path.write_text(source.replace("#@@CALIBRE_COMPAT_CODE@@", compat))
    PY

    printf '%s' "${moduleId}" > module_id.txt

    find . -name __pycache__ -prune -exec rm -rf {} +
    mkdir -p "$out"
    zip -q -r "$out/DeACSM_plugin.zip" .
  ''
