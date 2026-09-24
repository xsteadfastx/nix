{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Allow nheko (Matrix client) to build: it links libolm (olm), which upstream
  # has stopped maintaining -> marked insecure in nixpkgs. Opt in explicitly.
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  features.games = true;
  features.kodi = true;
  features.matrix = true;
  features.meshcore = true;
  features.neovim = true;
  features.wobcom = true;
  features.desktop = true;

  home-manager.users.marv = {
    imports = [ ../../home-manager/marv.nix ];
  };

  virtualisation.vmVariant = {
    users.users.marv.initialPassword = "notsafe";
    features.kodi = lib.mkForce false;
  };

  # dev stuff for chirpstack development
  networking.hosts = {
    "127.0.0.1" = [
      "chirpstack.localhost"
      "mqtt.localhost"
    ];
    "10.202.180.38" = [
      "primion.service.lsw.de" # fucked up primion
    ];
  };

  networking.firewall.allowedTCPPorts = [
    8080
    53317
  ]; # 53317 localsend

  hardware.graphics.enable = true;
  hardware.enableAllFirmware = true;

  # Bootloader.
  # MeshCore/CP210x USB-UART bridge (10c4:ea60): Chromium Web Serial is broken
  # on NixOS in two ways, both worked around by pre-setting the tty on plug-in:
  #
  # 1. Baud rate (glibc >= 2.42): B115200 is now the plain number 115200, but
  #    Chromium still does `c_cflag &= ~CBAUD; c_cflag |= B115200` + raw
  #    TCSETS2, which yields CBAUD=B0. The chip then keeps its previous speed
  #    (9600 on a fresh plug) and the app times out ("Failed to fetch device
  #    info"). Pre-set 115200 so the ignored speed change doesn't matter.
  #    ponytail: only covers 115200; a flasher switching baud mid-flash still
  #    breaks. Real fix: patch Chromium to use BOTHER + c_ospeed.
  # 2. VMIN=0 (left by pyserial: esptool, meshcore-cli, ...; the kernel keeps
  #    termios per tty index across unplug until reboot): Chromium inherits it,
  #    a non-blocking read() returns 0, and Chromium reports "The device has
  #    been lost". Restore min 1 time 0. Re-plug after using a pyserial tool.
  #
  # ModemManager's 80-mm-candidate.rules also AT-probes every USB-serial tty
  # as a possible modem and races the reset -- ignore this device.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ENV{ID_MM_DEVICE_IGNORE}="1", RUN+="${pkgs.coreutils}/bin/stty -F $devnode 115200 min 1 time 0"
  '';

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.kernelModules = [ "thunderbolt" ];

  # ZFS-compatible kernel. linuxPackages_latest drifted from 7.2.3 (thought to
  # be within ZFS 2.4.4's supported window) to 7.2.6, which then hit a real
  # kernel Oops during a normal ZFS pool sync at shutdown -- confirmed live,
  # 2026-09-22: page fault in __alloc_tagging_slab_free_hook, called from
  # kmem_cache_free <- spl_kmem_cache_free <- abd_free <- arc_hdr_free_abd
  # <- arc_write <- dbuf_write <- dbuf_sync_leaf, in ZFS's own dp_sync_taskq.
  # linuxPackages_7_2 is not a real pin -- it's a moving alias that currently
  # resolves to the exact same 7.2.6 as latest (confirmed), so it would have
  # kept the crash. Plain linuxPackages (nixpkgs' own default/stable track,
  # 6.18.x) is what ZFS is actually broadly tested against; the Lunar Lake xe
  # driver and IPU7 out-of-tree modules don't need bleeding-edge to work.
  boot.kernelPackages = pkgs.linuxPackages;
  boot.zfs.package = pkgs.zfs;
  boot.kernelParams = [ "drm_kms_helper.poll=1" ];

  # Disable ZFS block cloning (reflink/copy_file_range). ZFS 2.3+ defaults
  # zfs_bclone_enabled=1, but the clone path can deadlock the txg sync: on
  # 2026-07-16 a burst of `mv` (copy_file_range, likely a nix-fast-build) hung
  # in zfs_clone_range -> txg_wait_synced and froze the whole pool (hard
  # power-off required). Upstream kept this feature off by default for exactly
  # this bug class (openzfs/zfs #16680). This only stops *new* clones being
  # created; the deadlocking write path is then never entered.
  boot.extraModprobeConfig = "options zfs zfs_bclone_enabled=0";

  # Make a boot-time hang name its culprit instead of dying silently. On
  # 2026-09-23 a reboot froze ~20s in, in early udev with the console on xe,
  # leaving no panic, no oops and an empty pstore. The hung-task detector that
  # would have printed a stack never got to speak: its timeout is 120s but the
  # machine was powered off 58s after the last log line. Drop the timeout to
  # 60s and dump *every* CPU's stack -- all_cpu_backtrace shows what the stuck
  # task is blocking behind, which is what usually points at the driver.
  boot.kernel.sysctl = {
    "kernel.hung_task_timeout_secs" = 60;
    "kernel.hung_task_all_cpu_backtrace" = 1;
  };

  boot.initrd.availableKernelModules = [
    "nvme"
    "thunderbolt"
    "thunderbolt_net"
    "usbhid"
    "xhci_pci"
  ];

  hardware.enableRedistributableFirmware = true;

  hardware.cpu.intel.updateMicrocode = true;

  networking.hostName = "coltrane"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  nix.settings = {
    auto-optimise-store = true;

    trusted-users = [
      "root"
      "marv"
    ];
  };

  # Wayland: sway session (i3 removed).
  programs.sway.enable = true;

  # No login/display manager. greetd+regreet (cage-based Wayland greeter) was
  # a full compositor plus GTK theming just to draw a login box, and it
  # crashed back to a bare getty on first boot here with no visible error.
  # tty1 just runs NixOS's default `agetty` + password login; log in and run
  # `sway` by hand. Same PAM auth underneath as any greeter, one less thing
  # that can crash before you even get a shell -- and if sway itself fails,
  # you see the real error instead of a greeter silently retrying.

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
  ];

  # Keyboard layout is set by the sway config (input * xkb_layout de); no X server
  # or X11 keymap config is needed on this host.

  # Bigger tty fonts
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
  # German keymap for the console/TTY. Also what any bare getty types against.
  # base forces console.useXkbConfig (console follows the X keyboard), which
  # is dead on this host now that there is no X server, so we pin the map
  # directly. Plain "de" is kbd's legacy 7-bit-ASCII keymap -- it binds the ü
  # key to literal "@"/"\", no umlauts at all; "de-latin1" is the variant with
  # real ü/ö/ä, matching what every other German-keyboard tool here expects.
  console.keyMap = "de-latin1";
  console.useXkbConfig = lib.mkForce false;

  # systemd-vconsole-setup races the xe/simpledrm driver claiming the console
  # into graphics mode at early boot and silently skips ALL of its work --
  # font, unimap and keymap ("Configuration of first virtual console was
  # skipped, ignoring remaining ones" in the boot log). A known KMS/systemd
  # race, not specific to anything above.
  #
  # This used to re-apply just the keymap (`loadkeys`), which is not enough:
  # loadkeys resolves keysyms against the console's *current* mode and charset,
  # so on a console whose font/unimap were never applied, a non-ASCII keysym
  # cannot be represented and collapses -- typing ü produced "u". Re-run
  # systemd-vconsole-setup itself instead, so font + unimap + keymap all come
  # from /etc/vconsole.conf (i.e. from console.font / console.keyMap above):
  # nothing to keep in sync, and no half-configured console.
  #
  # before getty.target so the very first login prompt already accepts non-ASCII
  # input (a password with an umlaut in it is unwritable otherwise).
  systemd.services.force-console-setup = {
    description = "Re-apply console font+keymap after the early-KMS vconsole-setup race";
    wantedBy = [ "multi-user.target" ];
    before = [ "getty.target" ];
    after = [ "systemd-vconsole-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-vconsole-setup";
    };
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # no audio bell pls
    extraConfig.pipewire = {
      "99-silent-bell" = {
        "context.properties" = {
          "module.x11.bell" = false;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
    dmidecode
    nheko # Matrix client
    pciutils
    usbutils
    xclip
  ];

  # Needs to be enabled for completions
  programs.fish.enable = true;

  programs.appimage.enable = true;
  programs.appimage.binfmt = true;

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    pinentryPackage = pkgs.pinentry-gtk2;
  };

  services.pcscd.enable = true;

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale.overrideAttrs { doCheck = false; };
  };

  system.stateVersion = "25.11";

  # Laptop stuff
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = false;
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
    };
    charger = {
      governor = "performance";
      turbo = "auto";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  networking.firewall.allowedUDPPorts = [
    53 # networkmanager shared
    67 # networkmanager shared
    53317 # localsend
  ];

  # bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # scanner
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.epkowa ];
  };

  services.udev.packages = [ pkgs.epkowa ];

  # memory save
  systemd.oomd.enable = false;
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
    extraArgs = [
      # "-g"
      "--avoid"
      "^(X|i3.*|sway.*|sshd|systemd|ghostty|alacritty|zellij)$"
      "--prefer"
      "^(electron|chromium|firefox|chrome|libreoffice|gimp|slack)$"
    ];
  };

  services.resolved.enable = true;

  # Garbage: daily over 30d, but DON'T catch up after sleep.
  # nix.gc.persistent (default true) makes a gc missed while the laptop is asleep
  # fire the moment you wake it (~3 min CPU + GBs of disk read right after
  # lid-open). Setting it false skips the catch-up; the 5..15G min/max-free in
  # modules/base still auto-GC on low space, so a skipped scan can't grow the store.
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 30d";
    persistent = false;
  };

  # dell dockingstation
  services.hardware.bolt.enable = true;

  services.fwupd.enable = true; # firmware updates

  users.users.root.hashedPassword = "!";
  users.users.marv.extraGroups = [ "systemd-journal" ];

  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchDocked = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandlePowerKey = "suspend";
        HandlePowerKeyLongPress = "poweroff";
        HandleSleepKey = "suspend";
        HandleSleepKeyExternalPower = "suspend";
        HandleSuspendKey = "suspend";
        HandleSuspendKeyExternalPower = "suspend";
        LidSwitchIgnoreInhibited = "no";
        PowerKeyIgnoreInhibited = "yes";
        SleepKeyIgnoreInhibited = "yes";
        SuspendKeyIgnoreInhibited = "yes";
      };
    };
  };

  # Hard ceiling on tasks-per-session. systemd's own default is
  # TasksMax=infinity on login-session scopes, so a runaway fork loop (see
  # 2026-09-18 gping/ping storm: ~53k processes, ~17GB of swap) had nothing
  # to stop it short of ulimit -u (126401). This caps it far below any real
  # workload so a storm hits EAGAIN in seconds.
  #
  # This used to be services.logind.settings.Login.UserTasksMax, but systemd
  # removed that logind.conf option entirely -- confirmed live on 2026-09-22:
  # "systemd-logind: /etc/systemd/logind.conf:16: Support for option
  # UserTasksMax= has been removed", meaning the cap had been silently doing
  # nothing since it was added. The replacement lives on the user-.slice
  # template (matches every user-<uid>.slice instance) instead.
  systemd.slices."user-".sliceConfig.TasksMax = "10000";
}
