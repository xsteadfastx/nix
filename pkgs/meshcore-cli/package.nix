{
  fetchFromGitHub,
  python3Packages,
  ...
}:
let
  meshcore = python3Packages.buildPythonPackage rec {
    pname = "meshcore";
    version = "2.1.9";
    pyproject = true;

    src = python3Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-FhTOuVHhpYvmITgxfhXys8AJhRfYnMwCJ3fWJhMf53w=";
    };

    build-system = [ python3Packages.hatchling ];

    dependencies = [
      python3Packages.bleak
      python3Packages.pycayennelpp
      python3Packages.pyserial-asyncio
    ];

    pythonImportsCheck = [ "meshcore" ];
  };
in
python3Packages.buildPythonPackage {
  pname = "meshcore-cli";
  version = "unstable-2025-10-06";

  pyproject = true;

  src = fetchFromGitHub {
    owner = "meshcore-dev";
    repo = "meshcore-cli";
    rev = "62d4f67f63afd117e6aca8600b18889f4cda4bc3";
    sha256 = "sha256-HBcO/l9SfGX+HMwb8GYl3KT3QVJCfMfHJHY1d5u25mw=";
  };

  nativeBuildInputs = [
    python3Packages.hatchling
    python3Packages.setuptools
    python3Packages.wheel
  ];

  propagatedBuildInputs = [
    meshcore
    python3Packages.click
    python3Packages.prompt_toolkit
    python3Packages.pyserial
    python3Packages.requests
  ];

  doCheck = false;
}
