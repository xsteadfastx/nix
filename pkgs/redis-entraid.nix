{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

# redis/redis-py-entraid — Entra ID (Azure AD) credential provider for redis-py.
# Not in nixpkgs, so built from source. Only needed as a hard dependency of
# redis-mcp-server (redis/mcp-redis); the EntraID auth path is unused on our
# self-hosted Redis but the import is unconditional, so the dep can't be dropped.
python3Packages.buildPythonPackage rec {
  pname = "redis-entraid";
  version = "1.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "redis";
    repo = "redis-py-entraid";
    rev = "v${version}";
    hash = "sha256-rBfW89QhAIfmIgwvEMj3T8NaoKsPpW/wB1AEsSon3nw=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    redis
    pyjwt
    msal
    azure-identity
    requests
  ];

  pythonImportsCheck = [ "redis_entraid" ];

  doCheck = false;

  meta = {
    description = "Entra ID credentials provider implementation for the Redis-py client";
    homepage = "https://github.com/redis/redis-py-entraid";
    license = lib.licenses.mit;
  };
}
