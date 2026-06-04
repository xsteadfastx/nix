{
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nodejs_22,
}:

let
  version = "0.25.1";
  src = fetchFromGitHub {
    owner = "icereed";
    repo = "paperless-gpt";
    rev = "v${version}";
    hash = "sha256-bkBbvdDCFV2VeC42lArhZipklFD8DHmSqCARSlYl72Q=";
  };

  webApp = buildNpmPackage {
    pname = "paperless-gpt-web";
    inherit version src;
    nodejs = nodejs_22;
    sourceRoot = "${src.name}/web-app";
    npmDepsHash = "sha256-7PxH8kS28x8Sv5tD+Kohdv1CakKh8gIA9e9LGcWA960=";
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "paperless-gpt";
  inherit version src;

  vendorHash = "sha256-ZqJA9V4x4B7tAeIYbgSkFzj9ejhy6hfpEfAL90CQckw=";

  doCheck = false;

  preBuild = ''
    mkdir -p web-app/dist
    cp -r ${webApp}/* web-app/dist/
  '';

  postInstall = ''
    mkdir -p $out/share/paperless-gpt
    cp -r default_prompts $out/share/paperless-gpt/default-prompts
  '';

  meta = {
    description = "LLM-based auto-tagging and classification for paperless-ngx";
    homepage = "https://github.com/icereed/paperless-gpt";
    mainProgram = "paperless-gpt";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
