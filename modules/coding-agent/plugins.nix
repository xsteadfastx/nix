{ pkgs }:
let
  fetch = pkgs.fetchFromGitHub;
in
{
  superpowers = fetch {
    owner = "obra";
    repo = "superpowers";
    rev = "d884ae04edebef577e82ff7c4e143debd0bbec99";
    hash = "sha256-kHdQ9e44doBk2yYW88tMSCqVG8ycYcvJSZlrIziXhpA=";
  };
  ponytail = fetch {
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = "40e50d9e03242aa5dd53ac771950f9127362b25f";
    hash = "sha256-Pn6gPg0luOO0/I3dP4DzdvFn4Z7rjrK4Bbxf+4VBiYo=";
  };
}
