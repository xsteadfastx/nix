{ inputs, lib, ... }:
{
  meta = {
    nixpkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
    };
  };

  defaults =
    { config, ... }:
    {
      imports = [
        { nixpkgs.config.allowUnfree = true; }
        {
          _module.args = { inherit inputs; };
        }
      ];

      config = {
        deployment.targetHost = config.networking.hostName;
        deployment.targetUser = null;
      };
    };

  troy = import ./hosts/troy { inherit inputs lib; };
}
