{
  buildGo126Module,
  fetchFromGitHub,
  nix-update-script,
  ...
}:
buildGo126Module rec {
  pname = "localsend-go";
  version = "1.3.0";

  doCheck = false;

  src = fetchFromGitHub {
    owner = "meowrain";
    repo = "localsend-go";
    rev = "v${version}";
    hash = "sha256-qipDTrugEIiI04Jth+Ny14Bhk3Gc+ac5E5jH9mkPr00=";
  };

  vendorHash = "sha256-LtYzNt5YmBJWFB6tIidy+4xzgXOwcmy0Yms3Ppx7ooY=";
  ldflags = [
    "-s"
    "-w"
  ];

  env.CGO_ENABLED = 0;

  passthru.updateScript = nix-update-script { };
}
