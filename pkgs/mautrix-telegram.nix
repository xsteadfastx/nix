{
  buildGoModule,
  fetchFromGitHub,
  lib,
  olm, # cgo dep for mautrix/crypto/libolm — olm-3.2.16 is marked insecure; must be permitted
  pkg-config,
}:

buildGoModule rec {
  pname = "mautrix-telegram";
  version = "0.2611.0";

  src = fetchFromGitHub {
    owner = "mautrix";
    repo = "telegram";
    rev = "v${version}";
    hash = "sha256-z3jfjQyh47scBjHNThLn5DluSSS4fT21NAibWyD5Iqc=";
  };

  vendorHash = "sha256-byvTXR7gy6b/TIVfJ8bwMC/D9vqn6iwjoxBE1gkBNBc=";

  subPackages = [ "cmd/mautrix-telegram" ];

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ olm ];

  meta = {
    description = "A Matrix-Telegram puppeting bridge (Go rewrite, successors to mautrix-telegram)";
    homepage = "https://github.com/mautrix/telegram";
    license = lib.licenses.agpl3Only;
    mainProgram = "mautrix-telegram";
    platforms = lib.platforms.linux;
  };
}
