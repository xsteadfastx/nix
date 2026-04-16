{
  inputs,
  lib,
  ...
}:
{
  meta = {
    specialArgs = { inherit inputs; };
    nixpkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
    };
  };

  defaults =
    { config, ... }:
    {
      deployment.targetUser = null;
      deployment.targetHost = config.networking.hostName;
      nixpkgs.config.allowUnfree = true;
    };

  dipper = {
    deployment.tags = [ "server" ];
    imports = [ ./hosts/dipper ];
  };

  phil = {
    deployment.tags = [ "server" ];
    imports = [ ./hosts/phil ];
  };

  troy = {
    deployment.tags = [ "local" ];
    deployment.allowLocalDeployment = true;
    deployment.targetHost = lib.mkForce null;
    imports = [ ./hosts/troy ];
  };
}
