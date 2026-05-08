{
  config,
  lib,
  pkgs,
  ...
}:
let
  ipu7-camera-bins = pkgs.stdenv.mkDerivation {
    pname = "ipu7-camera-bins";
    version = "unstable-2025-01-15";
    src = pkgs.fetchFromGitHub {
      owner = "intel";
      repo = "ipu7-camera-bins";
      rev = "f4a353c7c2f0dc98416cd847a74724e8d6e07519";
      hash = "sha256-4LOFOIdBSMITNA1RtH8TDwPd+r/0lyTA6RBPeD0exO8=";
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
    version = "unstable-2025-01-15";
    src = pkgs.fetchFromGitHub {
      owner = "intel";
      repo = "ipu7-camera-hal";
      rev = "431ff3f46ef821458d973390c8a88687637290c2";
      hash = "sha256-/bSH+NJgVQ4HoW6yDlZGyg9EqTs+t0S3ZibVwl7IWf4=";
    };
    patches = [
      (pkgs.fetchpatch {
        url = "https://github.com/NixOS/nixpkgs/raw/01a5efa47470cf5800f4e8b352d7bbe24b81e788/pkgs/development/libraries/ipu7-camera-hal/0001-Fix-missing-definition-of-uint32_t.patch";
        hash = "sha256-hAo3upcozlGAL5kFmvVygdWeai8uy45uoyIEDi18kBM=";
      })
    ];
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
      ivsc-driver,
      kernel,
      kernelModuleMakeFlags,
      ...
    }:
    stdenv.mkDerivation {
      pname = "ipu7-drivers";
      version = "unstable-2025-11-12";
      src = fetchFromGitHub {
        owner = "intel";
        repo = "ipu7-drivers";
        rev = "fc335577f95bf6ca3afc706d1ceab8297db4f010";
        hash = "sha256-tRljxzo/WsFBLi/1YqxVRtXpSZzHRqIy3RZ8/heu7mI=";
      };
      patches = [
        (pkgs.fetchpatch {
          url = "https://github.com/NixOS/nixpkgs/raw/01a5efa47470cf5800f4e8b352d7bbe24b81e788/pkgs/os-specific/linux/ipu7-drivers/0001-media-ipu7-Stop-accessing-streams-configs-directly.patch";
          hash = "sha256-FMlw9fRMi1ZQlrP+uA36XwvdjZqiJFQy0G/57mfDmY8=";
        })
      ];
      postPatch = ''
        cp --no-preserve=mode --recursive --verbose \
          ${ivsc-driver.src}/backport-include \
          ${ivsc-driver.src}/drivers \
          ${ivsc-driver.src}/include \
          .
      '';
      nativeBuildInputs = kernel.moduleBuildDependencies;
      makeFlags = kernelModuleMakeFlags ++ [
        "KERNELRELEASE=${kernel.modDirVersion}"
        "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      ];
      enableParallelBuilding = true;
      preInstall = ''
        sed -i -e "s,INSTALL_MOD_DIR=,INSTALL_MOD_PATH=$out INSTALL_MOD_DIR=," Makefile
      '';
      installTargets = [ "modules_install" ];
      meta.broken = kernel.kernelOlder "6.12";
    }
  ) { };
in
{
  # The in-tree IPU7 driver (6.12+) only has ISYS; no PSYS was upstreamed.
  # ipu7-camera-hal requires PSYS for frame processing, so the out-of-tree
  # driver must load even on 6.12+ kernels (overrides the in-tree modules).
  boot.extraModulePackages = [ ipu7-drivers ];

  boot.kernelModules = [ "mei-vsc" ];

  # ipu_bridge (in-tree) conflicts with out-of-tree ipu_acpi for ACPI sensor setup
  boot.blacklistedKernelModules = [ "ipu_bridge" ];

  environment.etc."camera".source = "${ipu7x-camera-hal}/etc/camera";

  hardware.firmware = with pkgs; [
    ipu7-camera-bins
    ivsc-firmware
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="intel-ipu7-psys", MODE="0660", GROUP="video"
    KERNEL=="ipu7-psys*", MODE="0660", GROUP="video"
  '';

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
