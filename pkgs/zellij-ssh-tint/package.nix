{
  lib,
  pkgsCross,
  zellijPlugins,
}:
# Builds the zellij-ssh-tint WASM plugin. Mirrors how nixpkgs builds its own
# zellij plugins (see pkgs/by-name/ze/zellij/plugins in nixpkgs): cross-compile
# with `pkgsCross.wasm32-wasip1` so `cargo build` emits a .wasm, then flatten
# that single .wasm out through nixpkgs' `zellijPlugins.wrapper` so the
# derivation's output *is* the plugin file (what `load_plugins` points at).
#
# `nativeBuildInputs`/`RUSTFLAGS` are the wasm linker dance from that same
# nixpkgs directory (buildRustPackage prepends nativeBuildInputs to its own
# cargo/rustc, and forwards RUSTFLAGS). Don't set meta.platforms — buildRustPackage
# defaults it to `all ∩ rustc.targetPlatforms`, which admits the wasm32 host.
let
  wasm = pkgsCross.wasm32-wasip1;

  # unwrapped build dir -> contains one `.wasm` under $out
  unwrapped = wasm.rustPlatform.buildRustPackage {
    pname = "zellij-ssh-tint";
    version = "0.1.0";
    src = lib.cleanSource ./.;
    cargoHash = "sha256-L2yV5XoYDK7V7akn1pj/ss4rg0i/8uzinsqCgkUpp58=";

    nativeBuildInputs = [ wasm.lld ];
    RUSTFLAGS = "-C linker=wasm-ld";

    meta = {
      description = "Tint the zellij pane red while it runs an ssh session";
      longDescription = ''
        A passive zellij plugin: watches each pane's running command and colors
        panes that are `ssh <host>` (default `#3a0000`), so you can see at a
        glance that you're on a remote box. No shell wrapper, no changes on
        the remote host.
      '';
      license = lib.licenses.mit;
    };
  };
in
zellijPlugins.wrapper "ssh-tint" unwrapped
