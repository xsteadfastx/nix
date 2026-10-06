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

  features = {
    games = true;
    kodi = true;
    matrix = true;
    meshcore = true;
    neovim = true;
    wobcom = true;
    desktop = true;
  };

  # openfortivpn starts pppd without LCP echo, so a tunnel that outlives the
  # network (suspend) stays "up" over a dead socket: openfortivpn never notices,
  # keeps ppp0 + its pppd alive, and every later `wobcom-vpn` hangs until the
  # stale process is pkill'd by hand. Tear it down before sleeping; `wobcom-vpn`
  # reconnects on demand after resume.
  powerManagement.powerDownCommands = ''
    ${pkgs.procps}/bin/pkill -x openfortivpn || true
  '';

  home-manager.users.marv = {
    imports = [ ../../home-manager/marv.nix ];
  };

  virtualisation.vmVariant = {
    users.users.marv.initialPassword = "notsafe";
    features.kodi = lib.mkForce false;
  };

  boot = {
    # Bootloader.
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      systemd-boot.memtest86.enable = true;
    };

    binfmt.emulatedSystems = [ "aarch64-linux" ];

    kernelModules = [ "thunderbolt" ];

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
    kernelPackages = pkgs.linuxPackages;
    zfs.package = pkgs.zfs;
    kernelParams = [ "drm_kms_helper.poll=1" ];

    # Disable ZFS block cloning (reflink/copy_file_range). ZFS 2.3+ defaults
    # zfs_bclone_enabled=1, but the clone path can deadlock the txg sync: on
    # 2026-07-16 a burst of `mv` (copy_file_range, likely a nix-fast-build) hung
    # in zfs_clone_range -> txg_wait_synced and froze the whole pool (hard
    # power-off required). Upstream kept this feature off by default for exactly
    # this bug class (openzfs/zfs #16680). This only stops *new* clones being
    # created; the deadlocking write path is then never entered.
    extraModprobeConfig = "options zfs zfs_bclone_enabled=0";

    # Make a boot-time hang name its culprit instead of dying silently. On
    # 2026-09-23 a reboot froze ~20s in, in early udev with the console on xe,
    # leaving no panic, no oops and an empty pstore. The hung-task detector that
    # would have printed a stack never got to speak: its timeout is 120s but the
    # machine was powered off 58s after the last log line. Drop the timeout to
    # 60s and dump *every* CPU's stack -- all_cpu_backtrace shows what the stuck
    # task is blocking behind, which is what usually points at the driver.
    kernel.sysctl = {
      "kernel.hung_task_timeout_secs" = 60;
      "kernel.hung_task_all_cpu_backtrace" = 1;
      # xe GPU buffer churn (see the gfx.canvas.accelerated note in
      # home-manager/modules/firefox.nix) mixes unmovable pages into movable
      # pageblocks constantly; each such event boosted the watermarks and woke
      # kswapd, which then swapped into zram with 24 GiB free. Measured
      # 2026-10-05: 0 halved swap-out (23k -> 10k pages/s). Compaction still runs
      # on demand; kswapd now only works when memory is actually low.
      "vm.watermark_boost_factor" = 0;
    };

    initrd.availableKernelModules = [
      "nvme"
      "thunderbolt"
      "thunderbolt_net"
      "usbhid"
      "xhci_pci"
    ];
  };

  hardware = {
    graphics.enable = true;
    enableAllFirmware = true;

    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;

    # bluetooth
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # scanner
    sane = {
      enable = true;
      extraBackends = [ pkgs.epkowa ];
    };
  };

  networking = {
    # dev stuff for chirpstack development
    hosts = {
      "127.0.0.1" = [
        "chirpstack.localhost"
        "mqtt.localhost"
      ];
      "10.202.180.38" = [
        "primion.service.lsw.de" # fucked up primion
      ];
    };

    firewall = {
      allowedTCPPorts = [
        8080
        53317
      ]; # 53317 localsend

      # Open ports in the firewall.
      # networking.firewall.allowedTCPPorts = [ ... ];
      allowedUDPPorts = [
        53 # networkmanager shared
        67 # networkmanager shared
        53317 # localsend
      ];
    };

    hostName = "coltrane"; # Define your hostname.

    # Enable networking
    networkmanager.enable = true;
  };

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  i18n = {
    # Select internationalisation properties.
    defaultLocale = "en_US.UTF-8";

    extraLocaleSettings = {
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
  };

  # Garbage: fast-nix-gc instead of nix.gc — same daily 30d generation window,
  # same schedule, but seconds per run instead of minutes. Stock nix-gc spends
  # 1m45–4m30 just walking the reference graph on this ~118k-path store, even
  # when it deletes nothing.
  # On a laptop the timer never actually fires at midnight anyway: it stays
  # active while suspended, the 00:00 elapse passes, and systemd fires it on
  # resume — 22 of the last 25 nix-gc runs started in the same second as
  # `PM: suspend exit`. Persistent= only covers the timer being *inactive*
  # (powered off / not yet started): true catches up on the next boot, false
  # skips it. A seconds-long run is cheap enough to catch up.
  nix = {
    settings = {
      auto-optimise-store = true;

      trusted-users = [
        "root"
        "marv"
      ];
    };

    gc.automatic = false; # service unit stays defined, but has no timer
  };

  programs = {
    # Wayland: sway session (i3 removed).
    sway.enable = true;

    # Needs to be enabled for completions
    fish.enable = true;

    appimage = {
      enable = true;
      binfmt = true;
    };

    localsend = {
      enable = true;
      openFirewall = true;
    };

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    # programs.mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = false;
      pinentryPackage = pkgs.pinentry-gtk2;
    };
  };

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

  console = {
    # Bigger tty fonts
    font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
    # German keymap for the console/TTY. Also what any bare getty types against.
    # base forces console.useXkbConfig (console follows the X keyboard), which
    # is dead on this host now that there is no X server, so we pin the map
    # directly. Plain "de" is kbd's legacy 7-bit-ASCII keymap -- it binds the ü
    # key to literal "@"/"\", no umlauts at all; "de-latin1" is the variant with
    # real ü/ö/ä, matching what every other German-keyboard tool here expects.
    keyMap = "de-latin1";
    useXkbConfig = lib.mkForce false;
  };

  systemd = {
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
    services.force-console-setup = {
      description = "Re-apply console font+keymap after the early-KMS vconsole-setup race";
      wantedBy = [ "multi-user.target" ];
      before = [ "getty.target" ];
      after = [ "systemd-vconsole-setup.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.systemd.package}/lib/systemd/systemd-vconsole-setup";
      };
    };

    # memory save
    oomd.enable = false;

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
    slices."user-".sliceConfig.TasksMax = "10000";
  };

  security.rtkit.enable = true;

  # Enable sound with pipewire.
  services = {
    pulseaudio.enable = false;

    pipewire = {
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

    pcscd.enable = true;

    tailscale = {
      enable = true;
      package = pkgs.tailscale.overrideAttrs { doCheck = false; };
    };

    # Laptop stuff
    thermald.enable = true;
    power-profiles-daemon.enable = false;
    tlp.enable = false;
    auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
        };
        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };

    blueman.enable = true;

    udev.packages = [ pkgs.epkowa ];

    earlyoom = {
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

    resolved.enable = true;

    fast-nix-gc = {
      enable = true;
      automatic = true;
      dates = "daily";
      deleteOlderThan = "30d";
      persistent = true;
    };

    # dell dockingstation
    hardware.bolt.enable = true;

    fwupd.enable = true; # firmware updates

    logind = {
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
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
    dmidecode
    nheko # Matrix client
    pciutils
    usbutils
    xclip
  ];

  system.stateVersion = "25.11";

  users.users.root.hashedPassword = "!";
  users.users.marv.extraGroups = [ "systemd-journal" ];
}
