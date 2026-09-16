{
  buildGoModule,
  fetchFromGitHub,
  lib,
  olm, # cgo dep for mautrix/crypto/libolm — olm-3.2.16 is marked insecure; must be permitted
  pkg-config,
}:

buildGoModule rec {
  pname = "mautrix-telegram";
  version = "0.2608.0";

  src = fetchFromGitHub {
    owner = "mautrix";
    repo = "telegram";
    rev = "v${version}";
    hash = "sha256-EQ7c98GOaXaMcLF5xJfZ6tV+X9TKjNnd8a3ToJahNsE=";
  };

  vendorHash = "sha256-sh3CejNXhSLp2l4ZnfWwdwxqF+yzCn7/T4EWfVX84m8=";

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
