{ buildGo124Module, fetchFromGitHub, ... }:
buildGo124Module rec {
  pname = "localsend-go";
  version = "1.2.7";

  doCheck = false;

  src = fetchFromGitHub {
    owner = "meowrain";
    repo = "localsend-go";
    rev = "v${version}";
    hash = "sha256-Aier2AhFVi0jJ34VQtCGvOw1mHmfHH6a2697iYyZggo=";
  };

  vendorHash = "sha256-LtYzNt5YmBJWFB6tIidy+4xzgXOwcmy0Yms3Ppx7ooY=";
  ldflags = [
    "-s"
    "-w"
  ];

  env.CGO_ENABLED = 0;
}
