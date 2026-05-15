{ pkgs, ... }:
{
  # Keep USB/Thunderbolt controllers and ISY hub powered to prevent dropouts
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x64a0", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa831", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa833", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa834", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0xa87d", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="05e3", ATTRS{idProduct}=="0626", ATTR{power/control}="on"
  '';

  # Rebind ISY USB-C hub at boot to enumerate MST sub-ports (DP-1-3/DP-1-4).
  # The xe driver does not trigger HPD on the hub's DP alt mode at boot time.
  systemd.services.isy-hub-mst-init = {
    description = "Rebind ISY USB-C hub to restore MST topology after boot";
    wantedBy = [ "graphical.target" ];
    after = [
      "systemd-udev-settle.service"
      "graphical.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "isy-hub-mst-init" ''
        for i in $(seq 1 20); do
          HUB=$(for d in /sys/bus/usb/devices/*/; do
            vid=$(cat "$d/idVendor" 2>/dev/null)
            pid=$(cat "$d/idProduct" 2>/dev/null)
            if [ "$vid" = "05e3" ] && [ "$pid" = "0626" ]; then
              basename "$d"
            fi
          done)
          [ -n "$HUB" ] && break
          sleep 1
        done
        if [ -n "$HUB" ]; then
          # Skip rebind if MST sub-ports already active (e.g. with xe.enable_dc=0)
          if ls /sys/class/drm/ 2>/dev/null | grep -q "DP-1-3\|DP-1-4"; then
            exit 0
          fi
          echo "$HUB" > /sys/bus/usb/drivers/usb/unbind
          sleep 3
          echo "$HUB" > /sys/bus/usb/drivers/usb/bind
          sleep 5
          XAUTH=$(ls /run/user/*/Xauthority 2>/dev/null | head -1)
          if [ -n "$XAUTH" ]; then
            XUSER=$(stat -c '%U' "$XAUTH")
            runuser -u "$XUSER" -- env DISPLAY=:0 XAUTHORITY="$XAUTH" \
              ${pkgs.autorandr}/bin/autorandr --change --match-edid --default mobile || true
          fi
        fi
      '';
    };
  };

  # Oneshot service to rebind ISY hub, callable from user context (autorandr hooks).
  systemd.services.mst-restore = {
    description = "Rebind ISY USB-C hub to restore MST topology";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "mst-restore" ''
        HUB=""
        for d in /sys/bus/usb/devices/*/; do
          vid=$(cat "$d/idVendor" 2>/dev/null)
          pid=$(cat "$d/idProduct" 2>/dev/null)
          if [ "$vid" = "05e3" ] && [ "$pid" = "0626" ]; then
            HUB=$(basename "$d")
          fi
        done
        [ -z "$HUB" ] && exit 0
        echo "$HUB" > /sys/bus/usb/drivers/usb/unbind
        sleep 3
        echo "$HUB" > /sys/bus/usb/drivers/usb/bind
      '';
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "marv" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start mst-restore.service";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # ISY USB-C hub (Genesys Logic 05e3:0626) collapses MST topology on suspend.
  # Unbind/rebind the USB device to trigger DP HPD and restore MST sub-ports.
  powerManagement.resumeCommands = ''
    systemctl start mst-restore.service
    sleep 5
    XAUTH=$(ls /run/user/*/Xauthority 2>/dev/null | head -1)
    if [ -n "$XAUTH" ]; then
      XUSER=$(stat -c '%U' "$XAUTH")
      runuser -u "$XUSER" -- env DISPLAY=:0 XAUTHORITY="$XAUTH" \
        ${pkgs.autorandr}/bin/autorandr --change --match-edid --default mobile || true
    fi
  '';
}
