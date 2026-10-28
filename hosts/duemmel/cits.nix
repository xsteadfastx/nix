{
  pkgs,
  ...
}:
let
  # MAC of the ESP32-C5 as lowercase hex, no separators. The v2x2map web
  # flasher prints it as "Node-ID"; everything on the map hangs off
  # its/<nodeId>/... Mail it to the OpenTrafficMap people for a friendly name.
  nodeId = "3844be38ae9c";

  # /dev/ttyACM0 = the C5's native USB (v2x2map firmware).
  # /dev/ttyUSB0 = its UART bridge (reference firmware writes frames there).
  port = "/dev/ttyACM0";
in
{
  # Local mirror of the bridge's MQTT traffic. The bridge's --broker is
  # replace-not-add: cits1 has to be named explicitly next to the local one or
  # OpenTrafficMap stops receiving frames.
  services.mosquitto = {
    enable = true;
    # no persistence: the SD card is the only disk, and the mirror is live-only
    persistence = false;
    listeners = [
      {
        # loopback only: tailscaled forwards the tailnet's 1883 here below,
        # so the broker is never bound to wlan0 at all.
        address = "127.0.0.1";
        # skipping the password plugin keeps clients like mosquitto_sub/-paho
        # working without credentials.
        omitPasswordAuth = true;
        acl = [ "pattern readwrite its/#" ];
        settings.allow_anonymous = true;
      }
    ];
  };

  # Everything reachable from the tailnet goes through tailscaled, so no
  # firewall exception is needed. The bridge dashboard binds 127.0.0.1:8080
  # only -> https://duemmel.<tailnet>.ts.net/; the broker is mirrored as
  # mqtt://duemmel:1883. These routes persist on their own (`--bg` survives a
  # reboot), this unit just re-applies them when tailscaled's state is wiped.
  # On a fresh flash the node is not logged in yet: after `tailscale up`, run
  # `systemctl restart tailscale-serve`. Assumes services.tailscale.enable.
  systemd.services.tailscale-serve = {
    description = "Expose the ITS-G5 dashboard and MQTT mirror over Tailscale";
    wantedBy = [ "multi-user.target" ];
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.tailscale}/bin/tailscale serve --bg --yes --https=443 http://127.0.0.1:8080
      ${pkgs.tailscale}/bin/tailscale serve --bg --yes --tcp=1883 tcp://localhost:1883
    '';
  };

  systemd.services.its-g5 = {
    description = "OpenTrafficMap ITS-G5 bridge (ESP32-C5 over USB)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment.HOME = "/var/lib/its-g5";
    # the bridge shows a legal notice on first run and waits for ENTER;
    # pre-accept it, otherwise a headless service just exits.
    preStart = ''
      install -d -m0700 "$HOME/.config/v2x2map"
      [ -e "$HOME/.config/v2x2map/v2x2map.cfg" ] ||
        echo '{"legal_accepted": true}' > "$HOME/.config/v2x2map/v2x2map.cfg"
    '';
    serviceConfig = {
      ExecStart = ''
        ${pkgs.its-g5-bridge}/bin/its-g5-bridge \
          --node-id ${nodeId} \
          --port ${port} \
          --dashboard-port 8080 \
          --broker mqtts://cits1.opentrafficmap.org:8883 \
          --broker mqtt://localhost:1883
      '';
      Restart = "always";
      RestartSec = 5;
      DynamicUser = true;
      StateDirectory = "its-g5";
      WorkingDirectory = "/var/lib/its-g5";
      SupplementaryGroups = [ "dialout" ];
    };
  };

  # (re)start as soon as the board shows up: 303a = ESP32 native USB,
  # 1a86 = CH34x UART bridge.
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", TAG+="systemd", ENV{SYSTEMD_WANTS}+="its-g5.service"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", TAG+="systemd", ENV{SYSTEMD_WANTS}+="its-g5.service"
  '';
}
