{
  lib,
  rustPlatform,
  fetchCrate,
  runCommand,
  gtk3,
  pkg-config,
}:

# Waybar CFFI taskbar module for niri (LawnGnome/niri-taskbar).
#
# Waybar's own wlr/taskbar cannot order its buttons: wlr-foreign-toplevel-management
# defines no ordering at all (niri discussion #549), so buttons come out in
# whatever order the compositor sent the toplevels. This module reads niri's IPC
# instead and renders the buttons itself, ordered by workspace index and then by
# layout.pos_in_scrolling_layout, i.e. actual column/row order.
#
# The released crate pins niri-ipc to 25.11, whose Event enum predates the cast
# events niri 26.04 sends; the stream dies with "unknown variant CastsChanged"
# and the taskbar stops updating. Cargo.lock next to this file is the crate's
# lock with `cargo update -p niri-ipc --precise 26.4.0`
# (niri-ipc 26.4.0, serde_json 1.0.154, + zmij), which is all it takes.
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "niri-taskbar";
  version = "0.4.0+niri.25.11";

  src = runCommand "niri-taskbar-src" { nativeBuildInputs = [ ]; } ''
    cp -r ${
      fetchCrate {
        inherit (finalAttrs) pname version;
        hash = "sha256-Bb3wF8MvK5gxFi6fsCOFwEGz8gDR4L/sJk+vBlaPjy8=";
      }
    } $out
    chmod -R u+w $out
    substituteInPlace $out/Cargo.toml --replace-fail '>=25.11.0, <25.12.0' '>=26.4.0, <26.5.0'
    cp ${./Cargo.lock} $out/Cargo.lock
  '';

  cargoHash = "sha256-qcfqt8eDJgtJUBYUqIVWKZx0/wnRhG63qXmBnQoKEdc=";

  buildInputs = [ gtk3 ];
  nativeBuildInputs = [ pkg-config ];

  # Library only (crate-type = cdylib); there is no binary to test.
  doCheck = false;

  meta = {
    description = "Niri taskbar module for Waybar";
    homepage = "https://github.com/LawnGnome/niri-taskbar";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
