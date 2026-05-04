{
  lib,
  pkgs,
  pkgsUnstable,
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
    "10.202.180.38" = [
      "primion.service.lsw.de" # fucked up primion
    ];
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];

  hardware.graphics.enable = true;
  hardware.enableAllFirmware = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.kernelModules = [ "thunderbolt" ];

  boot.kernelPackages = pkgsUnstable.${pkgs.stdenv.hostPlatform.system}.linuxPackages;

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
    download-buffer-size = 524288000;

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

  # Bigger tty fonts
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

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

  environment.systemPackages = with pkgs; [
    brightnessctl
    dmidecode
    pciutils
    usbutils
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

  services.fwupd.enable = true; # firmware updates

  users.users.root.hashedPassword = "!";

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
