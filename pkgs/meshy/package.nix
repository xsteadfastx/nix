{
  lib,
  fetchFromGitea,
  gettext,
  glib,
  glib-networking,
  gobject-introspection,
  meson,
  ninja,
  pkg-config,
  wrapGAppsHook4,
  desktop-file-utils,
  geoclue2,
  gtk4,
  libadwaita,
  libshumate,
  python3Packages,
}:

# Meshy, the GTK4/libadwaita MeshCore desktop client (https://meshy-app.org).
# Upstream ships a derivation in build-aux/nix/flake.nix; this is that recipe
# with the repo's nixpkgs conventions (buildPythonApplication + meson, so the
# python deps arrive via PYTHONPATH) and pinned to the 26.09 release tag.
#
# Deliberately called with the TOP-LEVEL pkgs (not python3Packages.callPackage):
# `python3Packages.meson` is the PyPI meson module and ships no setup hook, so
# mesonConfigurePhase never gets installed and the build dies in buildPhase
# with "loading 'build.ninja': No such file or directory". The top-level
# `meson` is the app package that carries the hook.
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "meshy";
  version = "26.09";
  pyproject = false;

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "sesivany";
    repo = "meshy";
    tag = finalAttrs.version;
    hash = "sha256-U23MuusLKePra/qe+J1Co7aeIwmVmKTegE8BM8j4md4=";
  };

  nativeBuildInputs = [
    desktop-file-utils # update-desktop-database
    gettext
    glib # glib-compile-resources, glib-compile-schemas
    gobject-introspection
    meson
    ninja
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    geoclue2 # location service
    glib-networking # TLS for the map's tile downloads
    gtk4
    libadwaita
    libshumate # map view
  ];

  dependencies = with python3Packages; [
    pycryptodome # message crypto
    pygobject3
    pyserial # USB serial transport
    segno # the contact QR codes we display
  ];

  # Camera QR *scanning* is off: the scanner takes the XDG-portal camera stream
  # and feeds it to `pipewiresrc`/`pipewiredeviceprovider`, which live in
  # gst-plugin-pipewire (in upstream gst-plugins-rs) and are not in nixpkgs
  # (verified: no pipewire plugin in the gst-plugins-rs or gst-plugins-bad
  # output). Enabling it would show a "Scan QR Code" entry that always fails,
  # and pull in zbar/pyzbar plus the whole GStreamer stack for nothing.
  # ponytail: add `gst_all_1.gst-plugins-rs` + `python3Packages.pyzbar`/`zbar`
  # and drop this flag once nixpkgs packages gst-plugin-pipewire.
  mesonFlags = [ "-Dqr_scanner=false" ];

  # buildPythonApplication already wraps $out/bin/meshy (shebang + PYTHONPATH);
  # the GTK env comes from gappsWrapperArgs, so merge the two.
  dontWrapGApps = true;
  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  pythonImportsCheck = [ "meshy" ];

  meta = {
    description = "GTK4/libadwaita client for MeshCore companion radio nodes";
    longDescription = ''
      Meshy is a desktop client for MeshCore LoRa mesh networking devices. It
      connects over Bluetooth, USB serial or TCP, and offers encrypted direct
      and channel messaging, contact management, a map of the mesh, device
      monitoring and full radio configuration.
    '';
    homepage = "https://meshy-app.org";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ marv ];
    platforms = lib.platforms.linux;
    mainProgram = "meshy";
  };
})
