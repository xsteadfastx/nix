{
  fetchFromGitHub,
  gobject-introspection,
  libnotify,
  python3,
  python3Packages,
  stdenv,
  wrapGAppsNoGuiHook,
  ...
}:
stdenv.mkDerivation {
  pname = "imagingedge4linux";
  version = "0-unstable-2025-04-07";

  src = fetchFromGitHub {
    owner = "schorschii";
    repo = "ImagingEdge4Linux";
    rev = "12cff443eb39a125ba801b3b1ecbe892c93b860f";
    hash = "sha256-zE78ZlrKREb0zC4Ug9PSjcTO0vEpnE7mVuI+DNywy5w=";
  };

  doCheck = false;

  nativeBuildInputs = [
    wrapGAppsNoGuiHook
    gobject-introspection
  ];

  propagatedBuildInputs = [
    libnotify
    (python3.withPackages (pythonPackages: [
      python3Packages.pygobject3
      pythonPackages.requests
    ]))
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 imaging-edge.py $out/bin/imagingedge4linux
    runHook postInstall
  '';
}
