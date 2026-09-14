{
  lib,
  buildPythonApplication,
  fetchPypi,

  # build-system
  hatchling,

  # dependencies
  meshcore,
  textual,
  requests,
  aiohttp,
}:

# MeshCore companion-radio TUI (ekollof/meshtui, PyPI name `meshtui`).
#
# Not to be confused with jsaveker/meshtui (a different, larger project,
# packaged separately as `meshtui2`). Installed from the PyPI sdist to stay
# reproducible against the pinned channel.
buildPythonApplication (finalAttrs: {
  pname = "meshtui";
  version = "0.2.11";
  pyproject = true;

  src = fetchPypi {
    pname = finalAttrs.pname;
    version = finalAttrs.version;
    hash = "sha256-NBiogN2Rmk6H6mJasSXZ8em24RQt0tJbHcAxfKlzT/8=";
  };

  build-system = [ hatchling ];

  dependencies = [
    meshcore
    textual
    requests
    aiohttp
  ];

  pythonImportsCheck = [ "meshtui" ];

  meta = with lib; {
    description = "Terminal User Interface for MeshCore companion radios";
    homepage = "https://github.com/ekollof/meshtui";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "meshtui";
  };
})
