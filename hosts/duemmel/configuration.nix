{
  inputs,
  lib,
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

  wifiConf = "/boot/firmware/wifi.conf";
in
{
  imports = [ ./hardware-configuration.nix ];

  # native aarch64, not cross: the Pi builds/fetches these itself
  # (cache.nixos.org has native aarch64; cross artifacts it does not).
  nixpkgs.hostPlatform = "aarch64-linux";

  boot = {
    zfs.forceImportRoot = false;
    tmp = {
      useTmpfs = true;
      tmpfsSize = "50%";
    };
    # a Pi has no GRUB; the firmware/U-Boot chain reads extlinux.conf
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernel.sysctl = {
      # with zram as the only swap, prefer compressing to dropping page cache
      "vm.swappiness" = 100;
    };
  };

  # the bridge is small but python + TLS + a 2 GB Pi make swap pressure real;
  # zstd-compressed swap keeps us off the SD card.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  networking = {
    hostName = "duemmel";
    useNetworkd = true;
    interfaces.wlan0.useDHCP = true;
  };

  # The sd-image module declares this mount as "nofail,noauto" — but the WiFi
  # credentials live on it, so it has to be mounted at boot. Device and fsType
  # are repeated here because the hive build does not include the sd-image module.
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    # mkForce because the sd-image module's list is [ "nofail" "noauto" ];
    # lists merge, so without it "noauto" survives and the mount never happens.
    options = lib.mkForce [ "nofail" ];
  };

  # ssh marv@duemmel.local instead of hunting for the DHCP lease
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # WiFi credentials are NOT in this repo and NOT in the image: after flashing,
  # mount the FAT partition and drop in
  #   ssid=myssid
  #   psk=mysecret
  # at /boot/firmware/wifi.conf. Without the file the unit simply doesn't run.
  systemd.services.wpa-supplicant-wlan0 = {
    description = "wpa_supplicant on wlan0 (credentials from ${wifiConf})";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    unitConfig = {
      ConditionPathExists = wifiConf;
      RequiresMountsFor = "/boot/firmware";
    };
    path = [
      pkgs.coreutils
      pkgs.gnused
    ];
    preStart = ''
      install -d -m0700 /run/wpa_supplicant
      {
        echo 'ctrl_interface=DIR=/run/wpa_supplicant'
        echo 'network={'
        printf '  ssid="%s"\n' "$(sed -n 's/^ssid=//p' ${wifiConf})"
        printf '  psk="%s"\n' "$(sed -n 's/^psk=//p' ${wifiConf})"
        echo '}'
      } > /run/wpa_supplicant/wlan0.conf
    '';
    script = "exec ${pkgs.wpa_supplicant}/bin/wpa_supplicant -i wlan0 -c /run/wpa_supplicant/wlan0.conf";
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
    };
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
      ExecStart = "${pkgs.its-g5-bridge}/bin/its-g5-bridge --node-id ${nodeId} --port ${port} --dashboard-port 8080";
      Restart = "always";
      RestartSec = 5;
      DynamicUser = true;
      StateDirectory = "its-g5";
      WorkingDirectory = "/var/lib/its-g5";
      SupplementaryGroups = [ "dialout" ];
    };
  };

  # authenticate once with `ssh duemmel tailscale up`; the node key persists in
  # /var/lib/tailscale on the SD root (only /tmp is tmpfs).
  services.tailscale.enable = true;

  # (re)start as soon as the board shows up: 303a = ESP32 native USB,
  # 1a86 = CH34x UART bridge.
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", TAG+="systemd", ENV{SYSTEMD_WANTS}+="its-g5.service"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", TAG+="systemd", ENV{SYSTEMD_WANTS}+="its-g5.service"
  '';

  # nothing here needs to survive a reboot, and every write to the card is wear
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=64M
  '';

  fileSystems."/var/log" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=32M"
      "mode=0755"
      "noatime"
    ];
  };

  # brcmfmac (Pi 3 B+ / Pi 4) needs the board NVRAM blobs, which linux-firmware
  # does not ship. Comes from nixos-hardware's Pi wireless firmware package.
  hardware.firmware = [
    (pkgs.callPackage (
      inputs.nixos-hardware + "/raspberry-pi/common/raspberry-pi-wireless-firmware.nix"
    ) { })
  ];

  environment.systemPackages = with pkgs; [
    usbutils
    wpa_supplicant
  ];

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = lib.mkDefault "26.05";
}
