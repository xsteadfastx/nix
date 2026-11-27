{
  inputs,
  ...
}:
# nixpkgs-unstable as `pkgs.unstable`, imported once, centrally (avoids the
# "1000 instances of nixpkgs" antipattern). Plain on purpose: our overlays only
# apply to the main channel; a package that needs unstable picks it explicitly
# (`pkgs.unstable.callPackage` in pkgs/default.nix). `import`, not
# `.legacyPackages`, so `allowUnfree` can be set.
_final: prev: {
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
}
