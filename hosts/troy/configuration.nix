{
  lib,
  pkgs,
  ...
}:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelModules = [ "sg" ];

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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.trusted-users = [
    "root"
    "marv"
  ];

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  services.xserver.windowManager.i3.enable = true;

  # Try to fix wakeup problems

  # systemd.sleep.extraConfig = ''
  #   SuspendState=freeze
  # '';

  # https://github.com/kachick/dotfiles/issues/959
  # systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

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

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.marv = {
    isNormalUser = true;
    description = "marv";
    extraGroups = [
      "dialout"
      "docker"
      "lp"
      "networkmanager"
      "scanner"
      "wheel"
    ];
    # packages = with pkgs; [
    # ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    tmux
    vim
    wget
    brightnessctl
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
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  services.pcscd.enable = true;

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale.overrideAttrs { doCheck = false; };
  };

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

  # https://discourse.nixos.org/t/turn-off-autosuspend-for-usb/58933/3
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  networking.firewall.allowedUDPPorts = [
    53 # networkmanager shared
    67 # networkmanager shared
  ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

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
  services.earlyoom.enable = true;

  system.stateVersion = "24.11"; # Did you read the comment?
}
