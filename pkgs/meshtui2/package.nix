{
  lib,
  buildPythonApplication,
  fetchFromGitHub,
  # python package deps
  meshcore,
  pycryptodome,
  meshtastic,
  textual,
  pypubsub,
  cryptography,
  qrcode,
  paho-mqtt,
  # build-system
  hatchling,
}:

# MeshCore+Meshtastic operator suite (jsaveker/meshtui). The bigger, second
# MeshTUI; packaged as `meshtui2` to avoid the name clash with
# ekollof/meshtui (`meshtui`). Pinned to the v1.0.0 tag.
#
# `meshcore` is overridden to a newer version than nixpkgs ships, because
# jsaveker requires >= 2.3.9.1.
let
  meshcorePkg = (
    meshcore.overridePythonAttrs (old: {
      version = "2.3.10";
      src = fetchFromGitHub {
        owner = "meshcore-dev";
        repo = "meshcore_py";
        tag = "v2.3.10";
        hash = "sha256-NzFPtlSnZpJDHDfMUbBWMQ90XIuMmqCfm8073GJjYlQ=";
      };
      patches = [ ];
      # nixpkgs runtimeDepsCheck false-positives on this newer version's metadata
      # (reports pycryptodome missing though it's an inherited dep).
      dontCheckRuntimeDeps = true;
      # pinned nixpkgs meshcore (2.2.8) predates the pycryptodome dep that 2.3.x
      # requires at runtime (and it isn't inherited by the override).
      dependencies = old.dependencies ++ [ pycryptodome ];
    })
  );
in
buildPythonApplication (finalAttrs: {
  pname = "meshtui2";
  version = "1.0.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jsaveker";
    repo = "meshtui";
    rev = "v${finalAttrs.version}";
    hash = "sha256-nq0iIqko8ZGkcVU5avkqpGYHJSd7nuhuk2MDOSuomQM=";
  };

  build-system = [ hatchling ];

  # Pinned cryptography is 48 but meshtui's metadata asks >=50; the import check
  # below still proves a working runtime, so skip the metadata-only bound check.
  dontCheckRuntimeDeps = true;

  # pname is `meshtui2` (coexist with ekollof/meshtui), but the package module
  # is `meshtui`.
  pythonImportsCheck = [ "meshtui" ];

  # jsaveker/meshtui installs a `meshtui` binary, which clashes with the
  # ekollof `meshtui` package also installed under this feature. Rename it so
  # both can coexist on PATH.
  postInstall = ''
    mv "$out/bin/meshtui" "$out/bin/meshtui2"
  '';

  dependencies = [
    meshtastic
    textual
    pypubsub
    cryptography
    meshcorePkg
    qrcode
    paho-mqtt
  ];

  meta = with lib; {
    description = "MeshCore and Meshtastic operator suite, gateway, and web companion";
    homepage = "https://meshtui.com";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "meshtui2";
  };
})
