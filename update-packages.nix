{
  lib,
  writeShellApplication,
  nix-update,
  additions,
}:
# Runs the `passthru.updateScript` (nix-update-script) of each pkgs/ package with
# the patched nix-update below, against this flake.
let
  updatable = lib.filterAttrs (_: p: p.updateScript or null != null) additions;

  # Backport of 1.17's `nix flake prefetch` (1.16 fails on a dirty tree).
  # Drop once nixpkgs-unstable has 1.17; --replace-fail will tell you.
  nixUpdate = nix-update.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace nix_update/options.py \
        --replace-fail '["nix", "flake", "metadata", "--json"]' '["nix", "flake", "prefetch", "--json"]' \
        --replace-fail 'path = metadata.get("path")' 'path = metadata.get("storePath")'
    '';
  });
in
writeShellApplication {
  name = "update-packages";
  runtimeInputs = [ nixUpdate ];
  text = ''
    rc=0
    ${lib.concatMapAttrsStringSep "\n" (
      # updateScript is [ nix-update ...extraArgs ]; swap in the patched binary
      name: p:
      "nix-update --flake ${name} ${lib.escapeShellArgs (lib.drop 1 p.updateScript)} \"$@\" || rc=1"
    ) updatable}
    exit "$rc"
  '';
}
