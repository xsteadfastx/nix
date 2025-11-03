{
  inputs,
  ...
}:
{
  meta = {
    nixpkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
    };
  };

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

  troy = import ./hosts/troy { inherit inputs; };

  phil = import ./hosts/phil { inherit inputs; };
}
