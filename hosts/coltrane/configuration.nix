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

  home-manager.users.marv = {
    imports = [ ../../home-manager/marv.nix ];
    # lilium-voyager via the self-contained home-manager module.
    programs.liliumVoyager.enable = true;
  };

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
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.kernelModules = [ "thunderbolt" ];

  # ZFS-compatible default kernel (linuxPackages_latest outpaces ZFS and breaks the build)
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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  services.xserver.windowManager.i3.enable = true;

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
  ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Bigger tty fonts
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

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
    options = "--delete-older-than 30d";
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
}
