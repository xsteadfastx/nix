{ pkgs, ... }:
{
  # Keep USB/Thunderbolt controllers and ISY hub powered to prevent dropouts.
  # NOTE: the 0626 hub no longer auto-triggers mst-restore on re-enumeration.
  # The USB-hub rebind produces no DP/HPD events (DP runs over the TB/DP-altmode
  # path, not this USB hub), and firing it on resume destroyed the working MST
  # topology that autorandr had already detected. Power rules only here now.
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
          sleep 5
          echo "$HUB" > /sys/bus/usb/drivers/usb/bind
          # Poll for MST ports to appear (up to 30s)
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

  # Oneshot service to rebind ISY hub, callable from user context (autorandr hooks).
  systemd.services.mst-restore = {
    description = "Rebind ISY USB-C hub to restore MST topology";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "mst-restore" ''
        # During early boot isy-hub-mst-init handles MST init
        [ "$(cut -d. -f1 /proc/uptime)" -lt 120 ] && { echo "mst-restore: skipped (early boot)"; exit 0; }
        # Cooldown: rebind causes hub to re-enumerate, which would re-trigger
        # this service via udev. Skip if last run was less than 90 seconds ago.
        STAMP=/run/mst-restore-last
        NOW=$(cut -d. -f1 /proc/uptime)
        if [ -f "$STAMP" ]; then
          LAST=$(cat "$STAMP")
          AGE=$((NOW - LAST))
          if [ "$AGE" -lt 90 ]; then
            echo "mst-restore: skipped (cooldown, age=$AGE s)"
            exit 0
          fi
        fi
        echo "$NOW" > "$STAMP"
        HUB=""
        for d in /sys/bus/usb/devices/*/; do
          vid=$(cat "$d/idVendor" 2>/dev/null)
          pid=$(cat "$d/idProduct" 2>/dev/null)
          if [ "$vid" = "05e3" ] && [ "$pid" = "0626" ]; then
            HUB=$(basename "$d")
          fi
        done
        if [ -z "$HUB" ]; then
          echo "mst-restore: hub 05e3:0626 not found"
          exit 0
        fi
        if ls /sys/class/drm/ 2>/dev/null | grep -q "DP-1-3\|DP-1-4"; then
          echo "mst-restore: MST already active, skipping rebind"
          exit 0
        fi
        echo "mst-restore: rebinding hub $HUB"
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
        echo "mst-restore: done"
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

  # Clear stale workspace-layout state so the post-resume autorandr run starts
  # clean. (This used to claim it ran autorandr on resume — it never did; the
  # mst-reprobe service below now owns the resume re-apply.)
  powerManagement.resumeCommands = ''
    rm -f /run/user/1000/autorandr-ws-layout
    rm -f /run/user/1000/autorandr-current-ws
    rm -f /run/user/1000/autorandr-visible-ws
  '';

  # After long s2idle, xe relinks its DP connectors ASYNCHRONOUSLY and emits no
  # HPD event, so the DRM-hotplug udev rule never fires the second autorandr
  # that applies the external profile — monitors stay dark until autorandr is
  # run a SECOND time by hand (verified 2026-06-26). This service automates the
  # manually-verified fix: run `autorandr --change --match-edid` as marv once to
  # nudge the probe, poll sysfs until an external DP connector reports
  # 'connected' (xe relink is async, up to ~1 min observed), then run it again
  # to apply. Poll-until-connected instead of a fixed sleep, since the relink
  # latency is variable and never logged. Runs as marv with the X session env so
  # autorandr and its i3 postswitch hooks work; sysfs status is world-readable.
  systemd.services.mst-reprobe = {
    description = "Re-probe DP connectors after resume and re-apply autorandr";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    environment = {
      DISPLAY = ":0";
      XAUTHORITY = "/home/marv/.Xauthority";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "marv";
      ExecStart = pkgs.writeShellScript "mst-reprobe" ''
        autorandr="${pkgs.autorandr}/bin/autorandr --change --match-edid"
        # Run 1: nudge the connector probe.
        $autorandr || true
        # Poll for the async xe relink (120 s ceiling = 40 * 3 s).
        for _ in $(${pkgs.coreutils}/bin/seq 1 40); do
          for c in /sys/class/drm/card*-DP-*/status; do
            [ -e "$c" ] || continue
            if [ "$(${pkgs.coreutils}/bin/cat "$c")" = "connected" ]; then
              # Run 2: external connector is up — apply the external profile.
              $autorandr || true
              exit 0
            fi
          done
          ${pkgs.coreutils}/bin/sleep 3
        done
        # Timed out with no external DP (truly mobile): leave the run-1 state.
        exit 0
      '';
    };
  };
}
