{
  nix-update-script,
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "paperless-mcp";
  version = "2.3.0";

  src = fetchFromGitHub {
    owner = "baruchiro";
    repo = "paperless-mcp";
    tag = "v${version}";
    hash = "sha256-r1Ffhr+Eq+XwMy8AbVbEwcpMhvrjmKc38o2X8fKXz6Q=";
  };

  npmDepsHash = "sha256-dwxhJEvh4q5zMT+oerrXPu7jicOTwzKyWUhrsJyVi9g=";
  # package.json requires node >=24; TypeScript build (npm run build) is the default.
  nodejs = nodejs_24;

  # Don't let nixpkgs' npmInstallHook run `npm install` in-tree: it fires the
  # package's `prepack` (build + dxt pack), and the second tsc run then dies on
  # its own output (build/ is not excluded in tsconfig). Install by hand instead.
  dontNpmInstall = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/@baruchiro/paperless-mcp $out/bin
    cp -r build node_modules package.json LICENSE \
      $out/lib/node_modules/@baruchiro/paperless-mcp/
    chmod +x $out/lib/node_modules/@baruchiro/paperless-mcp/build/index.js
    ln -s $out/lib/node_modules/@baruchiro/paperless-mcp/build/index.js $out/bin/paperless-mcp
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "MCP server for paperless-ngx";
    homepage = "https://github.com/baruchiro/paperless-mcp";
    mainProgram = "paperless-mcp";
    license = lib.licenses.isc;
    platforms = lib.platforms.linux;
  };
}
