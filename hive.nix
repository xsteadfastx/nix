{ inputs, ... }:
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

  troy =
    { ... }:
    {
      imports = [
        ./modules/home-manager
        ./hosts/troy
        inputs.home-manager.nixosModules.home-manager
        inputs.nixos-hardware.nixosModules.dell-xps-13-7390
      ];

      xsfx.kodi = true;
      xsfx.neovim = true;
      xsfx.work = true;
      xsfx.x11 = true;

      home-manager.users.marv = import ./home-manager/marv.nix;
    };
}
