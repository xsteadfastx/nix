{ lib, pkgs, ... }:
let
  sharedHooks = {
    preswitch."reset-external" = ''
      export DISPLAY=:0
      export XAUTHORITY=/home/marv/.Xauthority
      export I3SOCK=$(${pkgs.i3}/bin/i3 --get-socketpath)
      if [ ! -f /run/user/1000/autorandr-current-ws ]; then
        ${pkgs.i3}/bin/i3-msg -t get_workspaces 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name' > /run/user/1000/autorandr-current-ws
      fi
      for output in $(${pkgs.xorg.xrandr}/bin/xrandr --query | grep " connected" | grep -v "eDP" | ${pkgs.gawk}/bin/awk '{print $1}'); do
        ${pkgs.xorg.xrandr}/bin/xrandr --output $output --off 2>/dev/null || true
      done
    '';
    postswitch."move-workspaces" = ''
      export DISPLAY=:0
      export XAUTHORITY=/home/marv/.Xauthority
      export I3SOCK=$(${pkgs.i3}/bin/i3 --get-socketpath)
      # Sort external outputs by X position — port-name agnostic
      SORTED=$(${pkgs.xorg.xrandr}/bin/xrandr --query | grep " connected" | grep -v "^eDP" | \
        ${pkgs.gawk}/bin/awk 'match($0, /[0-9]+x[0-9]+\+([0-9]+)\+/, a) {print a[1], $1}' | \
        sort -n | ${pkgs.gawk}/bin/awk '{print $2}')
      MIDDLE=$(echo "$SORTED" | sed -n '1p')
      RIGHT=$(echo "$SORTED" | sed -n '2p')
      if [ -f /run/user/1000/autorandr-ws-layout ]; then
        while IFS=' ' read -r ws out; do
          ${pkgs.i3}/bin/i3-msg "workspace $ws, move workspace to output $out" 2>/dev/null || true
        done < /run/user/1000/autorandr-ws-layout
        rm /run/user/1000/autorandr-ws-layout
      else
        if [ -n "$MIDDLE" ]; then
          ${pkgs.i3}/bin/i3-msg "workspace 1, move workspace to output $MIDDLE"
          ${pkgs.i3}/bin/i3-msg 'workspace 2, move workspace to output eDP-1'
          [ -n "$RIGHT" ] && ${pkgs.i3}/bin/i3-msg "workspace 3, move workspace to output $RIGHT"
        else
          [ -n "$RIGHT" ] && ${pkgs.i3}/bin/i3-msg "workspace 1, move workspace to output $RIGHT"
          ${pkgs.i3}/bin/i3-msg 'workspace 2, move workspace to output eDP-1'
        fi
      fi
      if [ -f /run/user/1000/autorandr-visible-ws ]; then
        while IFS=' ' read -r out ws; do
          ${pkgs.i3}/bin/i3-msg "workspace $ws" 2>/dev/null || true
        done < /run/user/1000/autorandr-visible-ws
        rm /run/user/1000/autorandr-visible-ws
      fi
      if [ -f /run/user/1000/autorandr-current-ws ]; then
        CURRENT_WS=$(cat /run/user/1000/autorandr-current-ws)
        rm /run/user/1000/autorandr-current-ws
        sleep 0.3
        [ -n "$CURRENT_WS" ] && ${pkgs.i3}/bin/i3-msg "workspace $CURRENT_WS"
      fi
    '';
    postswitch."disable-dpms" = ''
      export DISPLAY=:0
      export XAUTHORITY=/home/marv/.Xauthority
      ${pkgs.xorg.xset}/bin/xset -dpms
      ${pkgs.xorg.xset}/bin/xset s 60 60
    '';
  };

  eDP1 = {
    fingerprint = "00ffffffffffff0030e48b070000000000210104a51d1278072ef5a4544c97240d505400000001010101010101010101010101010101f07b80a070b03e453020360020b41000001a000000fd001e78999920010a202020202020000000fe00504637314e803133345755320a000000000002410cb2000100000b410a202001bf70207902002000133ce6248b07000000000017073133345755320a21001d400b08078007b00488428a54cd94974ed20d024554d05fd05f003412782600090200000000000100002200145fd704857f079f002f801f00af044600020005002501095fd7045fd7041e788081000be3058000e60601016a6a39000000000000a390";
    config = {
      enable = true;
      crtc = 0;
      primary = true;
      mode = "1920x1200";
      rate = "120.01";
    };
  };
in
{
  systemd.services.autorandr = {
    environment.DISPLAY = ":0";
    environment.XAUTHORITY = "/home/marv/.Xauthority";
    serviceConfig = {
      User = "marv";
      ExecStart = lib.mkForce "${pkgs.autorandr}/bin/autorandr --change --match-edid --default mobile";
      ExecStartPre = pkgs.writeShellScript "autorandr-pre" ''
        export I3SOCK=$(${pkgs.i3}/bin/i3 --get-socketpath 2>/dev/null)
        ${pkgs.i3}/bin/i3-msg -t get_workspaces 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name' > /run/user/1000/autorandr-current-ws
        ${pkgs.xorg.xrandr}/bin/xrandr --auto
        for output in $(${pkgs.xorg.xrandr}/bin/xrandr --query | grep " connected" | grep -v "eDP" | ${pkgs.gawk}/bin/awk '{print $1}'); do
          ${pkgs.xorg.xrandr}/bin/xrandr --output "$output" --off
        done
      '';
    };
  };

  services.autorandr = {
    enable = true;
    profiles = {
      "mobile" = {
        hooks.postswitch."restore-mst" = ''
          # Skip during early boot — isy-hub-mst-init handles MST init
          [ "$(cut -d. -f1 /proc/uptime)" -lt 120 ] && exit 0
          for d in /sys/bus/usb/devices/*/; do
            vid=$(cat "$d/idVendor" 2>/dev/null)
            pid=$(cat "$d/idProduct" 2>/dev/null)
            if [ "$vid" = "05e3" ] && [ "$pid" = "0626" ]; then
              /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl start mst-restore.service
              break
            fi
          done
        '';
        fingerprint = {
          eDP-1 = eDP1.fingerprint;
        };
        config = {
          eDP-1 = lib.mkMerge [
            eDP1.config
            { position = "0x0"; }
          ];
        };
      };

      "home" = {
        hooks = sharedHooks;
        fingerprint = {
          eDP-1 = eDP1.fingerprint;
          DP-1-4 = "00ffffffffffff0004210000000000000616010380643d008aee95a3544c99260f5054a54e0001010101010101010101010101010101662150b051001b30407036003f432100001e000000fd0018550f5010010a202020202020000000fc00484454560a20202020202020200000000000000000000000000000000000000130020324745090010403010201011f01131201110120230907038301000066030c00100080011d00bc52d01e20b8285540c48e2100001e011d80d0721c1620102c2580c48e2100001e8c0ad08a20e02d10103e9600138e210000188c0ad090204031200c405500138e21000018000000000000000000000000000000000000004e";
          DP-1-3 = "00ffffffffffff004c2db006343242432114010380301b782a78f1a655489b26125054bfef80714f8100814081809500b300a940950f023a801871382d40582c4500dd0c1100001e000000fd00384b1e5111010a202020202020000000fc00534d42323434300a2020202020000000ff004839585a3830363337330a2020017d02010400023a80d072382d40102c4580dd0c1100001e011d007251d01e206e285500dd0c1100001e011d00bc52d01e20b8285540151e1100001e8c0ad090204031200c405500dd1e110000188c0ad08a20e02d10103e9600dd1e1100001800000000000000000000000000000000000000000000000000000000000000000099";
        };
        config = {
          eDP-1 = lib.mkMerge [
            eDP1.config
            { position = "0x0"; }
          ];

          DP-1-4 = {
            enable = true;
            crtc = 1;
            position = "3840x0";
            mode = "1360x768";
            rate = "60.02";
          };

          DP-1-3 = {
            enable = true;
            crtc = 2;
            mode = "1920x1080";
            position = "1920x0";
            rate = "60.00";
          };
        };
      };

      "work" = {
        hooks = sharedHooks;
        fingerprint = {
          eDP-1 = eDP1.fingerprint;
          DP-1 = "00ffffffffffff0009d101834554000021180104a5351e783ed4a5ab5044a324145054a56b80d1c081c08180a9c0b300810001010101023a801871382d40582c4500dd0c1100001e000000ff004238453032353234534c300a20000000fd00324c1e5311000a202020202020000000fc0042656e5120424c323431300a2001a0020322f14f90050403020111121314060715161f2309070765030c00100083010000023a801871382d40582c4500132a2100001f011d8018711c1620582c2500132a2100009f011d007251d01e206e285500132a2100001e8c0ad08a20e02d10103e9600132a21000018000000000000000000000000000000000000000000eb";
          DP-2 = "00ffffffffffff0009d1218045540000111a010380351e782e4ca5a7554da226105054a56b80d1c0b300a9c08180810081c001010101023a801871382d40582c45000f282100001e000000ff0056344730303138353031390a20000000fd00324c1e5311000a202020202020000000fc0042656e51204c43440a20202020002f";
        };

        config = {
          eDP-1 = lib.mkMerge [
            eDP1.config
            { position = "0x0"; }
          ];

          DP-1 = {
            enable = true;
            crtc = 1;
            position = "1920x0";
            mode = "1920x1080";
            rate = "60.00";
          };

          DP-2 = {
            enable = true;
            crtc = 2;
            position = "3840x0";
            mode = "1920x1080";
            rate = "60.00";
          };
        };

      };
    };
  };

  # Disable autorandr service
  # systemd.services.autorandr.wantedBy = lib.mkForce [ ];
}
