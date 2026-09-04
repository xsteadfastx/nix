{
  config,
  lib,
  pkgs,
  ...
}:
let
  ipu7-camera-bins = pkgs.stdenv.mkDerivation {
    pname = "ipu7-camera-bins";
    version = "unstable-2026-07-17";
    src = pkgs.fetchFromGitHub {
      owner = "intel";
      repo = "ipu7-camera-bins";
      rev = "adf55525ab9d370828723b1ff8bee76ed7a492e8";
      hash = "sha256-azeQ7XoItcYmAuiKMiSJC5beACVNV/Yx2xNIZAPu29I=";
    };
    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      (lib.getLib pkgs.stdenv.cc.cc)
      pkgs.expat
      pkgs.zlib
    ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp --no-preserve=mode --recursive lib include $out/
      runHook postInstall
    '';
    postFixup = ''
      for solib in $out/lib/lib*.so.*; do
        solib=''${solib##*/}
        target=$out/lib/''${solib%.*}
        if [ ! -e "$target" ]; then
          ln -s "$solib" "$target"
        fi
      done
      for pcfile in $out/lib/pkgconfig/*.pc; do
        substituteInPlace $pcfile \
          --replace 'prefix=/usr' "prefix=$out"
      done
    '';
    meta.platforms = [ "x86_64-linux" ];
  };

  ipu7x-camera-hal = pkgs.stdenv.mkDerivation {
    pname = "ipu7x-camera-hal";
    # Tracks upstream HEAD. The OV02C10 black-frame regression reported in
    # intel/ipu7-camera-hal#52 (b94eee8) does NOT affect this unit: an A/B run
    # of e4a08b1 vs 11d8aff0, each with its own /etc/camera (the
    # OV02C10_MSHW0550.IPU7X.bin graph config differs between them), gave the
    # same picture -- last-frame Y mean 92.65 vs 92.99. Judge output on the
    # LAST of ~150 frames; the first buffer is always flat and AE needs ~30.
    version = "unstable-2026-08-12";
    src = pkgs.fetchFromGitHub {
      owner = "intel";
      repo = "ipu7-camera-hal";
      rev = "11d8aff0d1ddc16aef56c8e6518e08e2f936a95b";
      hash = "sha256-NSZVVOZKa3xhwitdKw4EZpukf5B/ObQC4GEDwHMmZ6s=";
    };
    nativeBuildInputs = [
      pkgs.cmake
      pkgs.pkg-config
    ];
    buildInputs = [
      pkgs.expat
      ipu7-camera-bins
      pkgs.jsoncpp
      pkgs.libtool
      pkgs.gst_all_1.gstreamer
      pkgs.gst_all_1.gst-plugins-base
      pkgs.libdrm
    ];
    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCMAKE_INSTALL_INCLUDEDIR=include"
      "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
      "-DBUILD_CAMHAL_ADAPTOR=ON"
      "-DBUILD_CAMHAL_PLUGIN=ON"
      "-DIPU_VERSIONS=ipu7x"
      "-DUSE_STATIC_GRAPH=ON"
      "-DUSE_STATIC_GRAPH_AUTOGEN=ON"
    ];
    NIX_CFLAGS_COMPILE = [ "-Wno-error" ];
    enableParallelBuilding = true;
    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace-fail 'set (CMAKE_CXX_STANDARD 11)' \
                       'set (CMAKE_CXX_STANDARD 17)'
      substituteInPlace src/platformdata/JsonParserBase.h \
        --replace-fail '<jsoncpp/json/json.h>' '<json/json.h>'
    '';
    postInstall = ''
      mkdir -p $out/include/ipu_lnl/
      cp -r $src/include $out/include/ipu_lnl/libcamhal
    '';
    postFixup = ''
      for solib in $out/lib/*.so; do
        patchelf --add-rpath "${ipu7-camera-bins}/lib" $solib
      done
    '';
    passthru = {
      ipuVersion = "ipu7x";
      ipuTarget = "ipu_lnl";
    };
  };

  icamerasrc-ipu7x = pkgs.callPackage (
    {
      stdenv,
      fetchFromGitHub,
      autoreconfHook,
      pkg-config,
      gst_all_1,
      libdrm,
      libva,
      ...
    }:
    stdenv.mkDerivation {
      pname = "icamerasrc-ipu7x";
      version = "unstable-2024-11-29";
      src = fetchFromGitHub {
        owner = "intel";
        repo = "icamerasrc";
        rev = "ee8526451ca1bb4957702de2f46138b63151f34c";
        hash = "sha256-GX67+A77/YQBwqqbBiDHrkiKb2CMAO5CJTwm1XyQOkg=";
      };
      nativeBuildInputs = [
        autoreconfHook
        pkg-config
      ];
      preConfigure = "export CHROME_SLIM_CAMHAL=ON";
      configureFlags = [ "--enable-gstdrmformat=yes" ];
      buildInputs = [
        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-bad
        ipu7x-camera-hal
        libdrm
        libva
      ];
      NIX_CFLAGS_COMPILE = [
        "-Wno-error"
        "-I${gst_all_1.gst-plugins-base.dev}/include/gstreamer-1.0"
      ];
      enableParallelBuilding = true;
      passthru.ipuVersion = "ipu7x";
    }
  ) { };

  ipu7-drivers = config.boot.kernelPackages.callPackage (
    {
      stdenv,
      fetchFromGitHub,
      kernel,
      kernelModuleMakeFlags,
      ...
    }:
    stdenv.mkDerivation {
      pname = "ipu7-drivers";
      version = "0-unstable-2026-08-12";
      src = fetchFromGitHub {
        owner = "intel";
        repo = "ipu7-drivers";
        rev = "495acc90feb09d8008c0a6228fb8bb4c6415ca62";
        hash = "sha256-a2hIJ4wMCHQeDb4gp+5pjLizJ/CCfA0JivVDWeqB4vY=";
      };
      nativeBuildInputs = kernel.moduleBuildDependencies;
      makeFlags = kernelModuleMakeFlags ++ [
        "KERNELRELEASE=${kernel.modDirVersion}"
        "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      ];
      enableParallelBuilding = true;
      preInstall = ''
        substituteInPlace Makefile \
          --replace-fail "INSTALL_MOD_DIR=" "INSTALL_MOD_PATH=$out INSTALL_MOD_DIR="
      '';
      installTargets = [ "modules_install" ];
      meta.broken = kernel.kernelOlder "6.12";
    }
  ) { };

  # intel_cvs: performs the sensor-ownership handshake with the CVS chip
  # (INTC10DE:00) that the OV02C10 sensor sits behind. Without it the sensor is
  # never released to the host, so ov02c10 reads reg 0x300a -> -121 timeout and
  # never probes. Not upstreamed; from intel/vision-drivers.
  intel-cvs-kmod = config.boot.kernelPackages.callPackage (
    {
      stdenv,
      fetchFromGitHub,
      kernel,
      kernelModuleMakeFlags,
      ...
    }:
    stdenv.mkDerivation {
      pname = "intel-cvs";
      version = "0-unstable-2026-05-07";
      src = fetchFromGitHub {
        owner = "intel";
        repo = "vision-drivers";
        rev = "845d6f8bdf66ff1f455901da9de5e00a53a83dce";
        hash = "sha256-i/qZN8GXyqaE6n6pRtxQLdmGhmPDjoArzVvflDmwuSs=";
      };
      nativeBuildInputs = kernel.moduleBuildDependencies;
      makeFlags = kernelModuleMakeFlags ++ [
        "KERNELRELEASE=${kernel.modDirVersion}"
        "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      ];
      enableParallelBuilding = true;
      preInstall = ''
        substituteInPlace Makefile \
          --replace-fail "INSTALL_MOD_DIR=" "INSTALL_MOD_PATH=$out INSTALL_MOD_DIR="
      '';
      installTargets = [ "modules_install" ];
      meta.broken = kernel.kernelOlder "6.6";
    }
  ) { };
in
{
  # The in-tree IPU7 core + ISYS (6.12+) enumerate the sensor via ipu_bridge;
  # only PSYS was never upstreamed. ipu7-drivers builds just the out-of-tree
  # intel-ipu7-psys module against the in-tree core. Do NOT blacklist ipu_bridge
  # nor load out-of-tree ipu_acpi: the current driver links against ipu_bridge
  # for ACPI sensor enumeration.
  boot.extraModulePackages = [
    ipu7-drivers
    intel-cvs-kmod
  ];

  # CVS hands the sensor to the host via the GPIO handshake; it also owns power.
  boot.kernelModules = [ "intel_cvs" ];

  environment.etc."camera".source = "${ipu7x-camera-hal}/etc/camera";

  hardware.firmware = with pkgs; [
    ipu7-camera-bins
    ivsc-firmware
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="intel-ipu7-psys", MODE="0660", GROUP="video"
    KERNEL=="ipu7-psys*", MODE="0660", GROUP="video"
  '';

  # The IPU7 exposes 32 raw ISYS capture nodes (/dev/video0-31, driver "isys").
  # WirePlumber would publish them as selectable cameras — they deliver nothing
  # and opening them blocks icamerasrc. Disabling the whole video-capture
  # monitor works but also hides the v4l2-relayd loopback, so PipeWire clients
  # (cheese, Firefox, anything using the camera portal) see no camera at all.
  # Instead: disable only the isys-driven nodes, keep the loopback, and turn off
  # the libcamera monitor (it publishes a "Built-in Front Camera" that drives
  # the sensor directly and fights icamerasrc for it).
  services.pipewire.wireplumber.extraConfig."51-ipu7-camera" = {
    "wireplumber.profiles" = {
      main = {
        # Explicit: the "hardware.video-capture" feature only *wants* both
        # monitors, and disabling libcamera stops v4l2 loading with it.
        "monitor.v4l2" = "required";
        "monitor.libcamera" = "disabled";
      };
    };
    "monitor.v4l2.rules" = [
      {
        matches = [ { "api.v4l2.cap.driver" = "isys"; } ];
        actions.update-props = {
          "node.disabled" = true;
          "device.disabled" = true;
        };
      }
    ];
  };

  services.v4l2-relayd.instances.ipu7 = {
    enable = true;
    cardLabel = "Intel MIPI Camera";
    extraPackages = [ icamerasrc-ipu7x ];
    input = {
      pipeline = "icamerasrc";
      format = "NV12";
    };
  };
}
