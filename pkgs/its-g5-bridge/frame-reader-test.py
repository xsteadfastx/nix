"""FrameReader: 14-byte (v2x2map) and 15-byte (RSSI byte) device headers."""
import struct
import sys
import types

for name in ("dashboard_server",):
    sys.modules[name] = types.ModuleType(name)
for name in ("paho", "paho.mqtt"):
    sys.modules[name] = types.ModuleType(name)
client = types.ModuleType("paho.mqtt.client"); client.Client = object
sys.modules["paho.mqtt.client"] = client
serial = types.ModuleType("serial"); serial.Serial = object
sys.modules["serial"] = serial
tools = types.ModuleType("serial.tools")
ports = types.ModuleType("serial.tools.list_ports"); ports.comports = lambda: []
tools.list_ports = ports
sys.modules["serial.tools"] = tools
sys.modules["serial.tools.list_ports"] = ports

import its_g5_bridge as m

CAM = bytes.fromhex(
    "88000000ffffffffffffde133b878e7dffffffffffffa0e22300"
    "aaaa03000000894712000501038100400380562050028000003201001400de133b878e7d"
)


def stream(payload, rssi_byte):
    hdr = struct.pack("<4sIIH", b"ITS5", 1234567890, 999, len(payload))
    return hdr + (bytes([rssi_byte]) if rssi_byte is not None else b"") + payload


def parse(data):
    r = m.FrameReader()
    return r, list(r.feed(data))


# 15-byte header: the RSSI byte must be dropped, payload intact (no truncation).
r, frames = parse(b"boot\r\n" + stream(CAM, 0x00) + b"[bt] log\r\n")
assert len(frames) == 1, frames
assert frames[0][2] == CAM, frames[0][2].hex()
assert r._hdr_extra == 1

# 14-byte header (v2x2map firmware): unchanged behaviour.
r, frames = parse(stream(CAM, None))
assert frames[0][2] == CAM, frames[0][2].hex()
assert r._hdr_extra == 0

# Detection sticks: a later frame needs no re-detection.
r, frames = parse(stream(CAM, 0x00) + stream(CAM, 0x00))
assert len(frames) == 2 and all(f[2] == CAM for f in frames), frames

# Split reads must not change the result.
data = stream(CAM, 0x00)
r = m.FrameReader()
out = []
for i in range(0, len(data), 7):
    out += list(r.feed(data[i:i + 7]))
assert out and out[0][2] == CAM

# The firmware's synthetic boot frame is not ITS-G5: the reader still yields
# it byte-exact (the caller labels it "link test" and drops it), and it must
# not desync the following real frames.
TEST = bytes.fromhex("deadbeef0102030405060708090a0b0c")
r, frames = parse(stream(TEST, 0x00))
assert [f[2] for f in frames] == [TEST], frames
assert not m._looks_80211(TEST)
r, frames = parse(stream(TEST, None))
assert [f[2] for f in frames] == [TEST], frames
r, frames = parse(stream(TEST, 0x00) + stream(CAM, 0x00) + stream(CAM, 0x00))
assert [f[2] for f in frames] == [TEST, CAM, CAM], frames
assert r._hdr_extra == 1

# The firmware's synthetic boot frame is not ITS-G5: the reader still yields
# it byte-exact (the caller labels it "link test" and drops it), and it must
# not desync the following real frames.
TEST = bytes.fromhex("deadbeef0102030405060708090a0b0c")
r, frames = parse(stream(TEST, 0x00))
assert [f[2] for f in frames] == [TEST], frames
assert not m._looks_80211(TEST)
r, frames = parse(stream(TEST, None))
assert [f[2] for f in frames] == [TEST], frames
r, frames = parse(stream(TEST, 0x00) + stream(CAM, 0x00) + stream(CAM, 0x00))
assert [f[2] for f in frames] == [TEST, CAM, CAM], frames
assert r._hdr_extra == 1

print("ok")
