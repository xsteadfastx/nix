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
  features.x11 = true;

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
  # MeshCore/CP210x USB-UART bridge (10c4:ea60): Chromium's Web Serial silently
  # fails to read the port unless the tty is in a default ("sane") line state.
  # Any program that leaves it non-default (CLI/SDK probes included) then makes
  # the web tools time out. Reset the line state on device add so the browser
  # can always talk to it.
  #
  # ModemManager's 80-mm-candidate.rules generically tags every USB-serial tty
  # (including this one -- confirmed via `udevadm info`: ID_MM_CANDIDATE=1) and
  # dbus-activates itself to AT-probe it as a possible cellular modem. That
  # probe is asynchronous and races the stty reset above, and reliably lands
  # after it -- confirmed via journalctl: ModemManager activated one second
  # after the CP210x attached. That's what actually corrupts the line (found
  # it wedged at 9600/ospeed 0, not a sane 115200), not just "some CLI left it
  # dirty". Tell ModemManager to ignore this device entirely so nothing ever
  # races the reset.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ENV{ID_MM_DEVICE_IGNORE}="1", RUN+="${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/stty sane -F $devnode'"
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
  # into graphics mode at early boot and silently skips loading the keymap
  # ("Configuration of first virtual console was skipped, ignoring remaining
  # ones" in the boot log) -- a known KMS/systemd race, not specific to
  # anything above. Re-apply it once multi-user is reached so a fallback tty
  # (recovery, a crashed session) never strands you on a US layout. Reads
  # console.keyMap rather than hardcoding it again so the two can't drift.
  systemd.services.force-console-keymap = {
    description = "Reapply console keymap after early-KMS vconsole-setup race";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-vconsole-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kbd}/bin/loadkeys ${config.console.keyMap}";
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
        # Hard ceiling on tasks-per-session. systemd's own default is
        # TasksMax=infinity on login-session scopes, so a runaway fork loop
        # (see 2026-09-18 gping/ping storm: ~53k processes, ~17GB of swap)
        # had nothing to stop it short of ulimit -u (126401). This caps it
        # far below any real workload so a storm hits EAGAIN in seconds.
        UserTasksMax = 10000;
      };
    };
  };
}
