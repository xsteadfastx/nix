{
  inputs,
  lib,
  ...
}:
let
  evalMeta = {
    nixpkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
  };
in
{
  meta = evalMeta;

  defaults =
    { config, ... }:
    {
      config = {
        _module.args = { inherit inputs; };
        deployment.targetHost = config.networking.hostName;
        deployment.targetUser = null;
        nixpkgs.config.allowUnfree = true;
      };
    };

  troy = import ./hosts/troy {
    pkgs = evalMeta.nixpkgs;
    inherit inputs lib;
  };

  phil = import ./hosts/phil { inherit inputs; };
}
