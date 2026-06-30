{ pkgs, ... }:
# The core plugins that pi needs to function as a coding agent.
# Defined here to be cached and shared across all hosts.
let
  piPermissionSystem =
    let
      extTarball = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@gotgenes/pi-permission-system/-/pi-permission-system-16.0.2.tgz";
        hash = "sha256-oq6bmJwZ6vwcpABCJ2SU+RteAckcMbU+hiniOJHMh5U=";
      };
      webTreeSitter = pkgs.fetchurl {
        url = "https://registry.npmjs.org/web-tree-sitter/-/web-tree-sitter-0.26.9.tgz";
        hash = "sha256-qs2KtgWPwTLlMVJtclNHarxWsMZGN+IDewIJIFwUaRs=";
      };
      treeSitterBash = pkgs.fetchurl {
        url = "https://registry.npmjs.org/tree-sitter-bash/-/tree-sitter-bash-0.25.1.tgz";
        hash = "sha256-1LKBlQjql8uJU//34wSmENRDAHvTlcjwOhXemorkpvk=";
      };
    in
    pkgs.runCommand "pi-permission-system-16.0.2" { } ''
      dest=$out/lib/pi-permission-system
      mkdir -p $dest/node_modules/web-tree-sitter $dest/node_modules/tree-sitter-bash
      tar -xzf ${extTarball} -C $dest --strip-components=1
      tar -xzf ${webTreeSitter} -C $dest/node_modules/web-tree-sitter --strip-components=1
      tar -xzf ${treeSitterBash} -C $dest/node_modules/tree-sitter-bash --strip-components=1
    '';

  piMcpAdapter = pkgs.buildNpmPackage {
    pname = "pi-mcp-adapter";
    version = "2.8.0";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/pi-mcp-adapter/-/pi-mcp-adapter-2.8.0.tgz";
      hash = "sha256-kSjvMGShpuRb+ImdzY9PPbIAZahOTtA+SoOlPLTvg2w=";
    };
    sourceRoot = "package";
    postPatch = ''
      ${pkgs.jq}/bin/jq 'del(.devDependencies)' package.json > package.json.tmp
      mv package.json.tmp package.json
      cp ${./lockfiles/pi-mcp-adapter.lock} package-lock.json
    '';
    npmDepsHash = "sha256-Uy8+2R4YcQ8H9SWQiewJrR0Uj8OK16+YlnM4rErsSoE=";
    dontNpmBuild = true;
    makeCacheWritable = true;
    installPhase = ''
      mkdir -p $out
      cp -r . $out
    '';
  };

  piBrowserTools = pkgs.buildNpmPackage {
    pname = "pi-browser-tools";
    version = "0.6.0";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@dreki-gg/pi-browser-tools/-/pi-browser-tools-0.6.0.tgz";
      hash = "sha256-A3vZzkrBVMOq+Ox1E2BIH9AKjQk6tsSy8/Oj6IzAj7c=";
    };
    sourceRoot = "package";
    postPatch = ''
      ${pkgs.jq}/bin/jq 'del(.devDependencies)' package.json > package.json.tmp
      mv package.json.tmp package.json
      cp ${./lockfiles/pi-browser-tools.lock} package-lock.json
    '';
    npmDepsHash = "sha256-f+skxoAJTvQRORXHv6E4d7fjZWrL+513tjeuYOynuVc=";
    npmDepsFetcherVersion = 2;
    dontNpmBuild = true;
    makeCacheWritable = true;
    npmFlags = [ "--ignore-scripts" ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out
      runHook postInstall
    '';
  };
in
{
  permissionSystem = piPermissionSystem;
  mcpAdapter = piMcpAdapter;
  browserTools = piBrowserTools;
}
