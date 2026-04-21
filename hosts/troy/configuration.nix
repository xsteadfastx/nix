{
  lib,
  pkgs,
  ...
}:
{
  xsfx.kodi = true;
  xsfx.neovim = true;
  xsfx.work = true;
  xsfx.x11 = true;

  home-manager.users.marv = import ../../home-manager/marv.nix;

  virtualisation.vmVariant = {
    users.users.marv.initialPassword = "notsafe";
    xsfx.kodi = lib.mkForce false;
  };

  # dev stuff for chirpstack development
  networking.hosts = {
    "127.0.0.1" = [
      "chirpstack.localhost"
      "mqtt.localhost"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];

  # zram
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 10;
  };

  boot.kernel.sysctl."vm.swappiness" = 100;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelModules = [
    "sg"
    "thunderbolt"
    "intel_wmi_thunderbolt"
  ];

  boot.initrd.availableKernelModules = [
    "dell_wmi"
    "drm_buddy"
    "i915"
    "intel_lpss_pci"
    "intel_wmi_thunderbolt"
    "nls_cp437"
    "nls_iso8859_1"
    "nvme"
    "r8152"
    "r8153_ecm"
    "thunderbolt"
    "ttm"
    "typec_ucsi"
    "uas"
    "ucsi_acpi"
    "usb_storage"
    "usbhid"
    "vfat"
    "video"
    "wmi"
    "xhci_pci"
  ];

  boot.initrd.kernelModules = [ "i915" ];

  boot.kernelParams = [
    "clearcpuid=514" # no throttling
    "i915.enable_dc=0"
    "i915.enable_fbc=0"
    "i915.enable_guc=3"
    "i915.enable_psr=0"
    "i915.modeset=1"
    "intel_idle.max_cstate=1"
    "intel_iommu=on,igfx_off"
    "intel_pstate=passive" # more kernel control
    "mem_sleep_default=deep"
    "pci=pcie_bus_perf"
    "pcie_aspm=off"
    "processor.ignore_ppc=1" # no throttling
    "resume=UUID=08110ec3-5356-48e3-b98c-f5afa622449d" # no battery
    "resume_delay=15"
    "thunderbolt.host_reset=false"
    "usbcore.autosuspend=-1" # https://discourse.nixos.org/t/turn-off-autosuspend-for-usb/58933/3
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  hardware.enableRedistributableFirmware = true;

  hardware.cpu.intel.updateMicrocode = true;

  networking.hostName = "troy"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  networking.hosts = {
    "10.202.180.38" = [
      "primion.service.lsw.de" # fucked up primion
    ];
  };

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
    download-buffer-size = 524288000;
    max-free = 10 * 1024 * 1024 * 1024; # 10GB
    min-free = 5 * 1024 * 1024 * 1024; # 5GB

    trusted-users = [
      "root"
      "marv"
    ];
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  services.xserver.windowManager.i3.enable = true;

  # Try to fix wakeup problems

  # systemd.sleep.extraConfig = ''
  #   SuspendState=freeze
  # '';

  # https://github.com/kachick/dotfiles/issues/959
  # systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
  ];

  # locking screen
  programs.xss-lock =
    let
      lock = pkgs.writeShellScriptBin "lock" ''
        XSECURELOCK_PASSWORD_PROMPT=time_hex \
        XSECURELOCK_FONT='JetBrainsMono Nerd Font' \
        ${pkgs.xsecurelock}/bin/xsecurelock
      '';
    in
    {
      enable = true;
      lockerCommand = "${lock}/bin/lock";
    };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "de";

  # Hidpi
  # bigger tty fonts
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
  # services.xserver.dpi = 180;
  # environment.variables = {
  #   GDK_SCALE = "2";
  #   GDK_DPI_SCALE = "0.5";
  #   _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2";
  # };

  services.autorandr =
    let
      eDP1 = {
        fingerprint = "00ffffffffffff004d10ad14000000002a1c0104a51d11780ede50a3544c99260f5054000000010101010101010101010101010101014dd000a0f0703e803020350026a510000018a4a600a0f0703e803020350026a510000018000000fe00305239394b804c513133334431000000000002410328011200000b010a20200041";
        config = {
          enable = true;
          crtc = 0;
          primary = true;
          mode = "1920x1080";
          rate = "59.96";
        };
      };
    in
    {
      enable = true;
      profiles = {
        "mobile" = {
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
          fingerprint = {
            eDP-1 = eDP1.fingerprint;
            DP-1 = "00ffffffffffff0004210000000000000616010380643d008aee95a3544c99260f5054a54e0001010101010101010101010101010101662150b051001b30407036003f432100001e000000fd0018550f5010000a202020202020000000fc00484454560a20202020202020200000000000000000000000000000000000000131020324745090050403070206011f14131216111520230907038301000066030c00100080011d00bc52d01e20b8285540c48e2100001e011d80d0721c1620102c2580c48e2100009e8c0ad08a20e02d10103e9600138e210000188c0ad090204031200c405500138e210000180000000000000000000000000000000000000083";
            DP-2-1 = "00ffffffffffff004c2db006343242432114010380301b782a78f1a655489b26125054bfef80714f8100814081809500b300a940950f023a801871382d40582c4500dd0c1100001e000000fd00384b1e5111000a202020202020000000fc00534d42323434300a2020202020000000ff004839585a3830363337330a2020017e02010400023a80d072382d40102c4580dd0c1100001e011d007251d01e206e285500dd0c1100001e011d00bc52d01e20b8285540151e1100001e8c0ad090204031200c405500dd1e110000188c0ad08a20e02d10103e9600dd1e1100001800000000000000000000000000000000000000000000000000000000000000000099";
          };
          config = {
            eDP-1 = lib.mkMerge [
              eDP1.config
              { position = "0x0"; }
            ];

            DP-1 = {
              enable = true;
              crtc = 1;
              position = "3840x0";
              mode = "1360x768";
              rate = "60.02";
            };

            DP-2-1 = {
              enable = true;
              crtc = 2;
              mode = "1920x1080";
              position = "1920x0";
              rate = "60.00";
            };
          };
        };

        "work" = {
          fingerprint = {
            eDP-1 = eDP1.fingerprint;
            DP-1 = "00ffffffffffff0009d1218045540000111a010380351e782e4ca5a7554da226105054a56b80d1c0b300a9c08180810081c001010101023a801871382d40582c45000f282100001e000000ff0056344730303138353031390a20000000fd00324c1e5311000a202020202020000000fc0042656e51204c43440a20202020002f";
            DP-2-2 = "00ffffffffffff0009d101834554000021180104a5351e783ed4a5ab5044a324145054a56b80d1c081c08180a9c0b300810001010101023a801871382d40582c4500dd0c1100001e000000ff004238453032353234534c300a20000000fd00324c1e5311000a202020202020000000fc0042656e5120424c323431300a2001a0020322f14f90050403020111121314060715161f2309070765030c00100083010000023a801871382d40582c4500132a2100001f011d8018711c1620582c2500132a2100009f011d007251d01e206e285500132a2100001e8c0ad08a20e02d10103e9600132a21000018000000000000000000000000000000000000000000eb";
          };

          config = {
            eDP-1 = lib.mkMerge [
              eDP1.config
              { position = "0x0"; }
            ];

            DP-2-2 = {
              enable = true;
              crtc = 1;
              position = "1920x0";
              mode = "1920x1080";
              rate = "60.00";
            };

            DP-1 = {
              enable = true;
              crtc = 1;
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

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = [
      pkgs.brlaser
      pkgs.brgenml1lpr
      pkgs.brgenml1cupswrapper
    ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    brightnessctl
    dmidecode
    pciutils
    tmux
    usbutils
    vim
    wget
  ];

  # Needs to be enabled for completions
  programs.fish.enable = true;

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

  # Laptop stuff
  services.throttled.enable = true;
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
    1700 # mqtt
  ];

  virtualisation.docker.enable = true;

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
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
    extraArgs = [
      # "-g"
      "--avoid"
      "^(X|i3.*|sshd|systemd|ghostty|alacritty)$"
      "--prefer"
      "^(electron|chromium|firefox|chrome|libreoffice|gimp|slack)$"
    ];
  };

  services.resolved.enable = true;

  # garbage
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  # dell dockingstation
  services.hardware.bolt.enable = true;

  # without battery
  boot.resumeDevice = "/dev/disk/by-uuid/08110ec3-5356-48e3-b98c-f5afa622449d";

  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "hibernate";
        HandleLidSwitchDocked = "hibernate";
        HandleLidSwitchExternalPower = "hibernate";
        HandlePowerKey = "hibernate";
        HandlePowerKeyLongPress = "poweroff";
        HandleSleepKey = "hibernate";
        HandleSleepKeyExternalPower = "hibernate";
        HandleSuspendKey = "hibernate";
        HandleSuspendKeyExternalPower = "hibernate";
        LidSwitchIgnoreInhibited = "no";
        PowerKeyIgnoreInhibited = "yes";
        SleepKeyIgnoreInhibited = "yes";
        SuspendKeyIgnoreInhibited = "yes";
      };
    };
  };

  services.fwupd.enable = true; # firmware updates

  system.stateVersion = "24.11";
}
