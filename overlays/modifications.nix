{
  inputs,
  ...
}:

# Changes to nixpkgs packages (version pins, patches), wrappers, and packages
# taken from flake inputs. Our own packages are in additions.nix.
final: prev:
let
  system = prev.stdenv.hostPlatform.system;

  # Expose only a tool's `bin/` to the profile (home.packages -> buildEnv).
  # Used for meshtui/meshtui2, which both ship site-packages/meshtui/ and
  # would collide if their full output trees were merged into one profile.
  profileBinOnly =
    name: pkg:
    prev.runCommand name { } ''
      mkdir -p $out/bin
      for f in "${pkg}/bin/"*; do
        [ -e "$f" ] || continue
        ln -s "$f" "$out/bin/$(basename "$f")"
      done
    '';

  # Version bump of a nixpkgs package; warns once nixpkgs has caught up.
  pin =
    name: attrs:
    let
      pkg = prev.${name}.overrideAttrs attrs;
    in
    prev.lib.warnIf (prev.lib.versionAtLeast prev.${name}.version pkg.version)
      "overlay: nixpkgs has ${name} ${prev.${name}.version} >= pinned ${pkg.version}, drop the override"
      pkg;
in
{
  # `gh` wrapper that authenticates from the sops-decrypted token file at
  # runtime. /run/secrets/gh-token is provisioned by sops-nix only on hosts
  # that declare sops.secrets."gh-token" (see hosts/coltrane/secrets.nix); on
  # hosts without it the file is absent, this is a no-op, and `gh` runs as-is
  # (its own auth, or unauthenticated). Reading the file at exec time keeps
  # the secret out of the nix store and picks up rotated tokens on the next
  # call. This is a separate wrapper package (not an override of `github-cli`)
  # that ships a `bin/gh`; it is added to the user's home.packages
  # (home-manager/modules/base.nix), so it lands on the shell PATH and the
  # coding agent inherits it from there. `github-cli` itself is left untouched
  # (keeping its completions/man pages) and is deliberately not on PATH, so
  # this wrapper is the only `gh`.
  #
  # Uses `final.github-cli` (not `prev.github-cli`) so it wraps the unstable
  # `github-cli` set by codingAgent below — both overlays compose into one
  # here, so `prev` would only see the stable `github-cli`.
  githubCliTokenWrapped = prev.writeShellScriptBin "gh" ''
    if [ -f /run/secrets/gh-token ]; then
      export GH_TOKEN=$(cat /run/secrets/gh-token)
    fi
    exec ${final.github-cli}/bin/gh "$@"
  '';

  # Go (bridgev2) mautrix-slack pinned past the "missing version data" login
  # bug (mautrix/slack#95, merged; lands in v0.2608.0), which aborts token-login
  # before the real credential check.
  # ponytail: the pin (nixpkgs 26.05) ships 26.04, so this stays until a flake
  # update brings nixpkgs past v0.2608.0 -- then delete this override.
  mautrix-slack = pin "mautrix-slack" rec {
    version = "26.11";
    tag = "v0.2611.0";
    src = prev.fetchFromGitHub {
      owner = "mautrix";
      repo = "slack";
      inherit tag;
      hash = "sha256-g8Tx+dkK+OWqchw1laJC8lInhOQk0d17dr4hwZIAqVQ=";
    };
    vendorHash = "sha256-1B4e4Ka+IYO1/d0GpGhR85hth3tnPCN7LVuWzyk/x9s=";
    # pkg/msgconv unit tests need env fixtures that don't exist in the nix
    # build sandbox; irrelevant to bridge runtime. Skip them.
    doCheck = false;
  };

  meshtuiProfile = profileBinOnly "meshtui" final.meshtui;
  meshtui2Profile = profileBinOnly "meshtui2" final.meshtui2;

  airmtp = inputs.airmtp.packages.${system}.default;

  # FluffyChat (from unstable) with the Catppuccin palette compiled in.
  fluffychat-catppuccin = prev.callPackage ../pkgs/fluffychat-catppuccin/package.nix {
    fluffychat = final.unstable.fluffychat;
    # the palette repo, not a built port: evaluation-only
    paletteFile = "${inputs.catppuccin.packages.${system}.palette}/palette.json";
    inherit (import ../lib/catppuccin.nix) flavor;
  };
  compose2nix = inputs.compose2nix.packages.${system}.default;

  # Hardens the flaky upstream `epkowa` plugin builds. Each plugin extracts
  # an Epson rpm via `rpm2cpio X | cpio -idmv`; stdenv sets `pipefail`, and
  # cpio exits after the archive trailer while rpm2cpio is still writing, so
  # the pipe intermittently dies with SIGPIPE (exit 141) even though
  # extraction succeeded. That race flakes nixos-rebuild/CI (see
  # NixOS/nixpkgs#541364).
  # ponytail: fixed upstream in NixOS/nixpkgs#556059 (merged, in unstable, scoped
  # per pipe). Kept only for the 26.05 pin.
  #
  # We drop pipefail for the install phase. This is SAFE against shipping a
  # broken package: cpio is the LAST command in the pipe, so without
  # pipefail the pipeline returns cpio's own exit status, and cpio returns
  # non-zero on any truncated/corrupt stream (0 only after reading a
  # complete archive to its trailer). The SIGPIPE only ever kills rpm2cpio
  # (the producer), and only after cpio has already consumed the full valid
  # archive and closed the pipe — the two can't coincide with a bad package.
  epkowa = prev.epkowa.override {
    plugins = builtins.mapAttrs (
      _: p:
      p.overrideAttrs (o: {
        installPhase = "set +o pipefail\n" + o.installPhase;
      })
    ) prev.epkowa.plugins;
  };

  attic = inputs.attic.packages.${system}.attic;

  cliamp = pin "cliamp" rec {
    version = "1.63.2";
    src = prev.fetchFromGitHub {
      owner = "bjarneo";
      repo = "cliamp";
      tag = "v${version}";
      hash = "sha256-HqFDT8jGvrKqb6bupvXqZ5ECpvColRB5dXPwcKCX4RQ=";
    };
    vendorHash = "sha256-WYyv0w5KFA15axb+NA9tClfc1H4Znj8kI2boR8XziXg=";
    meta = {
      description = "CLI amp – a simple audio volume controller for the terminal";
      homepage = "https://github.com/bjarneo/cliamp";
      license = prev.lib.licenses.mit;
    };
  };
}
