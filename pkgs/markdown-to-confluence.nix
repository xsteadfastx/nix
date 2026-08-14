{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

# hunyadi/md2conf — converts Markdown to Confluence Storage Format. Not in
# nixpkgs, so built from source. It's a hard runtime dep of mcp-atlassian
# (sooperset/mcp-atlassian), which uses it to render Confluence page content.
# Every runtime dep is already in nixpkgs at a compatible version, so plain
# buildPythonApplication resolves it — no lockfile machinery.
python3Packages.buildPythonApplication rec {
  pname = "markdown-to-confluence";
  version = "0.6.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "hunyadi";
    repo = "md2conf";
    tag = version;
    hash = "sha256-JpgIfBiYFIzDpDNtnDcXr2nYT9U2wQj9g65lKmst5yQ=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    cattrs
    lxml
    markdown
    orjson
    pymdown-extensions
    pyyaml
    pathspec
    requests
    truststore
  ];

  pythonImportsCheck = [ "md2conf" ];

  # dev-only deps (pytest) pull heavy trees and need a live Confluence.
  doCheck = false;

  meta = {
    description = "Publish Markdown files to Confluence wiki (Confluence Storage Format converter)";
    homepage = "https://github.com/hunyadi/md2conf";
    license = lib.licenses.mit;
    mainProgram = "md2conf";
  };
}
