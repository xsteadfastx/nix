{
  fetchFromGitHub,
  lib,
  makeWrapper,
  python3,
  stdenvNoCC,
}:
let
  python = python3.withPackages (ps: [
    ps.paho-mqtt
    ps.pyserial
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "its-g5-bridge";
  version = "unstable-2026-10-24";

  src = fetchFromGitHub {
    owner = "pit711";
    repo = "v2x2map";
    rev = "6872d24099dc1837a83403ae6abd4d10ad87b012";
    hash = "sha256-DDyC3sYhdjxbJl+t/gWFqVqSl3dr7fptAB5CDEEs2V0=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  # upstream starts with MQTT publishing disabled and waits for a click in its
  # web dashboard (runtime-only flag); a headless node must publish right away.
  postPatch = ''
    substituteInPlace bridge/its_g5_bridge.py \
      --replace-fail 'set_mqtt_state(enabled=False, available=False)' \
      'set_mqtt_state(enabled=True, available=False)'
  '';

  # Some firmware (0.2.5) writes an RSSI byte between the length field and the
  # 802.11 frame, others don't: with the fixed 14-byte header the payload is
  # shifted by one byte and its last byte is left in the buffer. The patch
  # detects the byte from the first frame and skips non-802.11 link tests.
  patches = [ ./frame-reader.patch ];

  checkPhase = ''
    cp ${./frame-reader-test.py} frame_reader_test.py
    ${python}/bin/python3 frame_reader_test.py
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 bridge/its_g5_bridge.py bridge/dashboard_server.py \
      bridge/dashboard.html -t $out/lib/its-g5-bridge
    makeWrapper ${python}/bin/python3 $out/bin/its-g5-bridge \
      --add-flags $out/lib/its-g5-bridge/its_g5_bridge.py
    runHook postInstall
  '';

  meta = {
    description = "ESP32-C5 ITS-G5/USB-to-MQTT bridge for opentrafficmap.org";
    homepage = "https://github.com/pit711/v2x2map";
    license = lib.licenses.mit;
    mainProgram = "its-g5-bridge";
  };
}
