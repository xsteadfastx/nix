{ writeShellScriptBin, chromium, ... }:
writeShellScriptBin "meshcore-web" "${chromium}/bin/chromium-browser --app-id=gkndnkfbikecfgkfkhbdpkcpnokgcfaf"
