{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  makeWrapper,
  nodejs_26,
  poppler-utils,
}:

# Zettelrobbe asks an LLM to name title, tags, correspondent and type for new
# paperless-ngx documents — the one thing paperless's own classifier cannot do,
# because it only picks from names it has already seen.
#
# Upstream ships a Dockerfile, not a library: nothing in package.json is a usable
# `bin`, and the image is only an entrypoint (root → gosu → pm2). None of that is
# needed here: systemd runs the process as an unprivileged user, and server.js
# resolves its assets from __dirname (read-only store is fine) while keeping its
# state in $PWD/data — hence WorkingDirectory=/var/lib/zettelrobbe in the unit.
buildNpmPackage rec {
  pname = "zettelrobbe";
  version = "2026.11.03";

  src = fetchFromGitHub {
    owner = "admonstrator";
    repo = "zettelrobbe";
    tag = "v${version}";
    hash = "sha256-zatUgKu7FO3fUPWFmgpCbRnz1W4ttuAn0hPb0gDHfi8=";
  };

  npmDepsHash = "sha256-PJwzms12gaOJE/ZJXmYLDdHZ+djTD2x1dig2arYRonY=";
  nodejs = nodejs_26; # matches upstream .nvmrc

  nativeBuildInputs = [ makeWrapper ];

  dontNpmBuild = true;
  dontNpmInstall = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/zettelrobbe $out/bin
    cp -r \
      server.js package.json schemas.js swagger.js \
      config models routes middleware services scripts views public OPENAPI \
      node_modules \
      $out/lib/zettelrobbe/
    makeWrapper ${nodejs_26}/bin/node $out/bin/zettelrobbe \
      --add-flags $out/lib/zettelrobbe/server.js \
      --prefix PATH : ${lib.makeBinPath [ poppler-utils ]}
    runHook postInstall
  '';

  meta = {
    description = "AI tagging for paperless-ngx (fork of clusterzx/paperless-ai)";
    homepage = "https://zettelrob.be";
    mainProgram = "zettelrobbe";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
