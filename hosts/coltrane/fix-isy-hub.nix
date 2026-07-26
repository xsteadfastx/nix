{ pkgs, ... }:
{
  # Keep USB/Thunderbolt controllers and the ISY USB-C hub powered to prevent
  # dropouts. The MST-recovery machinery that used to live here (mst-restore
  # hub rebind, udev SYSTEMD_WANTS trigger, resumeCommands autorandr, sudo
  # rule) was removed: the USB-hub rebind produces no DP/HPD events (DP runs
  # over the TB/DP-alt-mode path, not this hub) and the typec alt-mode
  # `active` toggle is firmware-blocked ("firmware doesn't support alternate
  # mode overriding"), so no software lever recovers a wedged xe MST topology
  # after long s2idle — only a physical replug or reboot does. autorandr
  # --match-edid (udev-triggered on hotplug) still applies the right profile
  # and the move-workspaces postswitch hook restores the layout on plug/unlock.
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
  # Boot-only; resume recovery is not software-recoverable (see comment above).
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
          # Skip rebind if MST sub-ports already active
          if ls /sys/class/drm/ 2>/dev/null | grep -q "DP-1-3\|DP-1-4"; then
            exit 0
          fi
          echo "$HUB" > /sys/bus/usb/drivers/usb/unbind
          sleep 5
          echo "$HUB" > /sys/bus/usb/drivers/usb/bind
          for i in $(seq 1 30); do
            ls /sys/class/drm/ 2>/dev/null | grep -q "DP-1-3\|DP-1-4" && break
            sleep 1
          done
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
}
