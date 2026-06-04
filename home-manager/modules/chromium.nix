{
  lib,
  pkgs,
  nixosConfig,
  pkgsUnstable,
  ...
}:

let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  home.activation.syncPkiCertsToNssDb = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.pki/nssdb"
    timeout 5 ${pkgs.nssTools}/bin/certutil -d sql:"$HOME/.pki/nssdb" -N --empty-password 2>/dev/null || true
    for cert in ${lib.escapeShellArgs nixosConfig.security.pki.certificateFiles}; do
      name=$(basename "$cert" .crt)
      timeout 5 ${pkgs.nssTools}/bin/certutil -d sql:"$HOME/.pki/nssdb" -A -t "CT,," -n "$name" -i "$cert" 2>/dev/null || true
    done
  '';

  programs.chromium = {
    enable = true;
    package = pkgsUnstable.chromium.override { enableWideVine = true; };
    commandLineArgs = [
      "--audio-buffer-size=4096"
    ];
    extensions = [
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # dark reader
      { id = "gfapcejdoghpoidkfodoiiffaaibpaem"; } # dracula
      { id = "ddkjiahejlhfcafbddmgiahcphecmpfh"; } # ublock origin lite
      { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # vimium
      { id = "edibdbjcniadpccecjdfdjjppcpchdlm"; } # i still dont care about cookies
      { id = "dhdgffkkebhmkfjojejmpbldmpobfkfo"; } # tampermonkey
    ];
  };
}
