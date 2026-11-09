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
#
# `local-fixes.patch` adds what the released crate does not do:
#
# - a button for the windows on the bar's own output only, and only while
#   their workspace is the one that output is showing. Upstream lists every
#   window of every workspace in every bar, in niri's layout order.
# - it waits for the bar's output to be known instead of resolving it once at
#   module init. GDK learns a window's output from the compositor's
#   `wl_surface.enter`, which arrives after `init` has run; a bar created
#   before that resolved to "show every window" and stayed there until the
#   next workspace switch. Waybar recreates all its bars whenever the monitor
#   set changes, so that was every dock/unplug, not just login.
# - it rebuilds that filter on window events too, not just on WorkspacesChanged.
#   On resume the outputs churn (eDP-1 + a transient DP-1, then DP-6/DP-7);
#   a bar whose filter was built while GDK and niri still disagreed stayed on
#   "show every window" for good, because niri sends no WorkspacesChanged once
#   the layout has settled (2026-11-09, after a weekend's sleep).
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
    patch -p1 --batch --forward -d $out < ${./local-fixes.patch}
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
