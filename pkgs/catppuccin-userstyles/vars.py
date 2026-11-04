"""Turn a userstyle's `@var` header into LESS defaults (what Stylus does)."""
import json
import re
import sys

src = open(sys.argv[1], encoding="utf-8").read()
header = src.split("==/UserStyle==")[0]
overrides = dict(arg.split("=", 1) for arg in sys.argv[2:])
for m in re.finditer(r"^@var\s+(\w+)\s+([\w-]+)\s+(\"[^\"]*\"|'[^']*'|\S+)\s+(.+?)\s*$", header, re.M):
    kind, name, _label, raw = m.groups()
    if name in overrides:
        value = overrides[name]
    elif kind == "select":
        opts = json.loads(raw) if raw.startswith("[") else list(json.loads(raw).keys())
        pick = next((o for o in opts if o.split(":")[0].endswith("*") or o.endswith("*")), opts[0])
        value = pick.split(":")[0].rstrip("*")
    elif kind in ("checkbox",):
        value = raw.strip()
    elif kind in ("text",):
        value = raw.strip()
    elif kind in ("number", "range"):
        # [default, min, max, step, 'unit'] -- the unit may be single-quoted
        spec = json.loads(raw.replace("'", '"')) if raw.startswith("[") else [raw]
        value = str(spec[0]) + (spec[4] if len(spec) > 4 else "")
    else:  # color and anything else: take as is
        value = raw.strip()
    print(f"@{name}: {value};")
