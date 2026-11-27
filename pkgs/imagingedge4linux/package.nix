{
  nix-update-script,
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
  version = "0.2-unstable-2026-10-18";

  src = fetchFromGitHub {
    owner = "schorschii";
    repo = "ImagingEdge4Linux";
    rev = "5317d416ed5296fc5a3343442b17276afb9ccc77";
    hash = "sha256-viI7G61XJ6o+cYNjIQQ0NGR2PYb6IQvUJmapYQ3+qHE=";
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

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
}
