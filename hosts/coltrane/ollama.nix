{
  pkgs,
  pkgsUnstable,
  config,
  ...
}:
let
  # Use the NixOS-wrapped podman: its wrapper injects /run/wrappers/bin
  # (setuid newuidmap/newgidmap) and the rootless helpers (crun, conmon,
  # fuse-overlayfs, pasta, ...) onto PATH. The raw pkgs.podman lacks this and
  # fails at cold start with "newuidmap: executable file not found in $PATH".
  podman = config.virtualisation.podman.package;

  # Version-tagged image so a bump forces a rebuild (a static tag would not).
  ollamaVersion = "0.31.1";
  imageTag = "ollama-sycl:${ollamaVersion}";

  dockerfile = pkgs.writeText "Dockerfile.ollama-sycl" ''
    ARG OLLAMA_VERSION=${ollamaVersion}
    ARG COMPUTE_RUNTIME_VERSION=26.18.38308.1
    ARG LEVEL_ZERO_VERSION=1.28.2
    ARG IGC_VERSION=2.34.4
    ARG IGC_BUILD=21428
    ARG GMM_VERSION=22.10.0

    FROM intel/oneapi-basekit:2025.2.2-0-devel-ubuntu24.04 AS sycl-builder

    ARG OLLAMA_VERSION

    RUN git clone --depth 1 --branch v''${OLLAMA_VERSION} \
      https://github.com/ollama/ollama.git /ollama

    WORKDIR /ollama

    RUN cmake -S llama/server -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER=icx \
      -DCMAKE_CXX_COMPILER=icpx \
      -DBUILD_SHARED_LIBS=ON \
      -DGGML_BACKEND_DL=ON \
      -DGGML_NATIVE=OFF \
      -DGGML_OPENMP=OFF \
      -DGGML_SYCL=ON \
      -DGGML_SYCL_TARGET=INTEL \
      -DGGML_SYCL_F16=ON && \
      cmake --build build --parallel $(nproc) --target ggml-sycl && \
      mkdir -p /sycl-runner && \
      find /ollama/build -name "libggml-sycl.so" -exec cp {} /sycl-runner/ \;

    RUN \
      cp /opt/intel/oneapi/compiler/latest/lib/libsycl.so* /sycl-runner/ && \
      find /opt/intel/oneapi -name 'libur_loader.so*' | head -3 | xargs -I{} cp {} /sycl-runner/ && \
      find /opt/intel/oneapi -name 'libur_adapter_level_zero.so*' | head -3 | xargs -I{} cp {} /sycl-runner/ && \
      find /opt/intel/oneapi -maxdepth 4 -name 'libumf.so*' | head -3 | xargs -I{} cp {} /sycl-runner/ && \
      cp /opt/intel/oneapi/dnnl/latest/lib/libdnnl.so* /sycl-runner/ 2>/dev/null; \
      cp /opt/intel/oneapi/mkl/latest/lib/libmkl_core.so* /sycl-runner/ && \
      cp /opt/intel/oneapi/mkl/latest/lib/libmkl_intel_ilp64.so* /sycl-runner/ && \
      cp /opt/intel/oneapi/mkl/latest/lib/libmkl_sycl_blas.so* /sycl-runner/ && \
      cp /opt/intel/oneapi/mkl/latest/lib/libmkl_tbb_thread.so* /sycl-runner/ && \
      cp /opt/intel/oneapi/tbb/latest/lib/intel64/gcc*/libtbb.so* /sycl-runner/ && \
      cp /opt/intel/oneapi/compiler/latest/lib/libsvml.so /sycl-runner/ && \
      cp /opt/intel/oneapi/compiler/latest/lib/libimf.so /sycl-runner/ && \
      cp /opt/intel/oneapi/compiler/latest/lib/libintlc.so* /sycl-runner/ && \
      cp /opt/intel/oneapi/compiler/latest/lib/libirng.so /sycl-runner/ && \
      cp /opt/intel/oneapi/compiler/latest/lib/libiomp5.so /sycl-runner/ && \
      cp /opt/intel/oneapi/compiler/latest/lib/libpi_level_zero.so* /sycl-runner/ 2>/dev/null; \
      cp /opt/intel/oneapi/compiler/latest/lib/libsycl-fallback*.spv /sycl-runner/ && \
      cp /opt/intel/oneapi/compiler/latest/lib/libsycl-native*.spv /sycl-runner/ && \
      strip --strip-unneeded /sycl-runner/*.so* 2>/dev/null; true

    FROM ubuntu:24.04
    ARG DEBIAN_FRONTEND=noninteractive
    ARG OLLAMA_VERSION
    ARG COMPUTE_RUNTIME_VERSION
    ARG LEVEL_ZERO_VERSION
    ARG IGC_VERSION
    ARG IGC_BUILD
    ARG GMM_VERSION

    RUN apt-get update && \
      apt-get install --no-install-recommends -q -y \
      ca-certificates wget zstd ocl-icd-libopencl1 libhwloc15 && \
      rm -rf /var/lib/apt/lists/*

    RUN mkdir -p /tmp/gpu && cd /tmp/gpu && \
      wget https://github.com/oneapi-src/level-zero/releases/download/v''${LEVEL_ZERO_VERSION}/level-zero_''${LEVEL_ZERO_VERSION}+u24.04_amd64.deb && \
      wget https://github.com/intel/intel-graphics-compiler/releases/download/v''${IGC_VERSION}/intel-igc-core-2_''${IGC_VERSION}+''${IGC_BUILD}_amd64.deb && \
      wget https://github.com/intel/intel-graphics-compiler/releases/download/v''${IGC_VERSION}/intel-igc-opencl-2_''${IGC_VERSION}+''${IGC_BUILD}_amd64.deb && \
      wget https://github.com/intel/compute-runtime/releases/download/''${COMPUTE_RUNTIME_VERSION}/intel-ocloc_''${COMPUTE_RUNTIME_VERSION}-0_amd64.deb && \
      wget https://github.com/intel/compute-runtime/releases/download/''${COMPUTE_RUNTIME_VERSION}/intel-opencl-icd_''${COMPUTE_RUNTIME_VERSION}-0_amd64.deb && \
      wget https://github.com/intel/compute-runtime/releases/download/''${COMPUTE_RUNTIME_VERSION}/libigdgmm12_''${GMM_VERSION}_amd64.deb && \
      wget https://github.com/intel/compute-runtime/releases/download/''${COMPUTE_RUNTIME_VERSION}/libze-intel-gpu1_''${COMPUTE_RUNTIME_VERSION}-0_amd64.deb && \
      dpkg -i *.deb && rm -rf /tmp/gpu

    RUN wget -qO- "https://github.com/ollama/ollama/releases/download/v''${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" | \
      zstd -d | tar -xf - -C /usr && \
      rm -rf /usr/lib/ollama/cuda_* /usr/lib/ollama/vulkan

    COPY --from=sycl-builder /sycl-runner/ /usr/lib/ollama/sycl/

    ENV OLLAMA_HOST=0.0.0.0
    ENV OLLAMA_KEEP_ALIVE=24h
    ENV ZES_ENABLE_SYSMAN=1
    ENV ONEAPI_DEVICE_SELECTOR=level_zero:0

    EXPOSE 11434
    ENTRYPOINT ["/usr/bin/ollama"]
    CMD ["serve"]
  '';

  buildScript = pkgs.writeShellScript "build-ollama-sycl" ''
    if ! ${podman}/bin/podman image inspect ${imageTag} > /dev/null 2>&1; then
      echo "Building ${imageTag} (~20 min)..."
      ctx=$(mktemp -d)
      ${podman}/bin/podman build -t ${imageTag} -f ${dockerfile} "$ctx"
      rmdir "$ctx"
    fi
  '';

  runScript = pkgs.writeShellScript "run-ollama-sycl" ''
    exec ${podman}/bin/podman run --rm \
      --pull=never \
      --name ollama \
      --device /dev/dri \
      -p 127.0.0.1:11434:11434 \
      -v "$HOME/.local/share/ollama:/root/.ollama" \
      -v "$HOME/.cache/ollama-sycl:/root/.cache" \
      -e ONEAPI_DEVICE_SELECTOR=level_zero:0 \
      -e ZES_ENABLE_SYSMAN=1 \
      -e SYCL_CACHE_PERSISTENT=1 \
      -e SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1 \
      -e UR_L0_USE_IMMEDIATE_COMMANDLISTS=1 \
      -e OLLAMA_KEEP_ALIVE=30m \
      -e OLLAMA_CONTEXT_LENGTH=32768 \
      -e OLLAMA_FLASH_ATTENTION=1 \
      ${imageTag}
  '';
in
{
  systemd.user.tmpfiles.rules = [
    "d %h/.local/share/ollama 0755 - - -"
    "d %h/.cache/ollama-sycl 0755 - - -"
  ];

  environment.systemPackages = [
    pkgs.ollama
    pkgsUnstable.opencode
  ];

  users.users.marv.extraGroups = [
    "video"
    "render"
  ];

  systemd.user.services.ollama-sycl-build = {
    description = "Build ollama-sycl image";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = buildScript;
      TimeoutStartSec = 0;
    };
  };

  systemd.user.services.ollama = {
    description = "Ollama SYCL";
    wantedBy = [ "default.target" ];
    after = [ "ollama-sycl-build.service" ];
    requires = [ "ollama-sycl-build.service" ];
    serviceConfig = {
      ExecStart = runScript;
      ExecStop = "${podman}/bin/podman stop ollama";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
