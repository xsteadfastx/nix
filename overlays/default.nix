{ inputs, ... }:

# Nix overlay for custom packages
# Provides overrides and additional packages used by the system.
# Maintainer: Marvin Preuss <marv@yourdomain.com>

let
  # Custom packages / overrides. Factored into a named overlay so it can be
  # applied to BOTH the stable base pkgs AND the nested unstable instance
  # (below) without duplicating definitions. It deliberately does NOT define
  # `unstable` itself — applying it to the unstable import would otherwise
  # recurse forever (unstable.unstable.unstable...).
  packageOverrides =
    final: prev:
    let
      system = prev.stdenv.hostPlatform.system;
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

      localsend-go = prev.callPackage ../pkgs/localsend-go.nix { };

      trippy-dracula = prev.callPackage ../pkgs/trippy-dracula.nix { };

      airmtp = inputs.airmtp.packages.${system}.default;
      compose2nix = inputs.compose2nix.packages.${system}.default;

      bumblebee-status = prev.bumblebee-status.override {
        # Add the plugins we actually use in this configuration.
        plugins = p: [
          p.cpu
          p.nic
          p.pipewire
        ];
      };

      # Hardens the flaky upstream `epkowa` plugin builds. Each plugin extracts
      # an Epson rpm via `rpm2cpio X | cpio -idmv`; stdenv sets `pipefail`, and
      # cpio exits after the archive trailer while rpm2cpio is still writing, so
      # the pipe intermittently dies with SIGPIPE (exit 141) even though
      # extraction succeeded. That race flakes nixos-rebuild/CI (see
      # NixOS/nixpkgs#541364).
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

      quickemu = inputs.quickemu.packages.${system}.default;

      imagingedge4linux = prev.callPackage ../pkgs/imagingedge4linux/package.nix { };
      importsony = prev.callPackage ../pkgs/importsony/package.nix { };
      importsony-jpegs = prev.callPackage ../pkgs/importsony-jpegs/package.nix { };
      paperless-gpt = prev.callPackage ../pkgs/paperless-gpt/package.nix { };

      xsaneGimp = prev.xsane.override { gimpSupport = true; };

      attic = inputs.attic.packages.${system}.attic;

      cliamp = prev.cliamp.overrideAttrs (rec {
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
          maintainers = with prev.lib.maintainers; [ marv ];
        };
      });
    };

  # (overlays/default.nix) — see modules/base. The coding-agent repo's overlay
  # now provides the pi/mcp-* packages as plain pkgs.* attrs; overlays.default
  # here is only the custom package overrides + the single unstable instance.
  # Coding-agent packages: single-sourced from the coding-agent repo's own
  # overlay, so we don't duplicate their definitions here. The repo overlay
  # builds the Python MCP servers (mcp-atlassian, redis-mcp) from source against
  # whatever channel it's applied to — those need recent deps (cattrs>=26.1,
  # lxml>=6.1) that only exist on nixos-unstable, so we apply it to this repo's
  # nested `unstable` instance (below), then surface the names at the top level
  # where the coding-agent module reads them as plain `pkgs.*`.
  codingAgentOverlay = inputs.coding-agent.overlays.default;

  # The package names the coding-agent module consumes as top-level pkgs.*.
  codingAgentPkgs = [
    "pi-coding-agent"
    "claude-code"
    "postgres-mcp"
    "mcp-atlassian"
    "redis-mcp-server"
    "agent-browser"
    "mcp-nixos"
    "mcp-server-git"
    "mcp-grafana"
    "github-mcp-server"
    "context7-mcp"
    "mcp-server-sequential-thinking"
    "mcp-server-memory"
    "netbox-mcp-server"
    "activity-mcp"
    "playwright-mcp"
    "mcp-proxy"
    "github-cli"
    "ripgrep"
  ];
in
final: prev:
(packageOverrides final prev)
// {
  # Single nixpkgs-unstable instance, exposed as `pkgs.unstable`. Importing a
  # second channel once, centrally, is the idiomatic way to mix channels — it
  # avoids the "1000 instances of nixpkgs" antipattern of scattering
  # `import nixpkgs-unstable {...}` across modules. Reachable anywhere `pkgs`
  # is (system and, via useGlobalPkgs, home-manager) as `pkgs.unstable.<name>`.
  #
  # `import` (not `.legacyPackages`) is required for `allowUnfree`; the same
  # packageOverrides are applied so custom packages resolve identically on both
  # channels (`pkgs.foo` = stable, `pkgs.unstable.foo` = unstable). The
  # coding-agent repo's overlay is applied here too, so the Python MCP servers
  # build against unstable (recent deps).
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
    overlays = [
      packageOverrides
      codingAgentOverlay
    ];
  };
}
// (builtins.listToAttrs (
  map (name: {
    inherit name;
    value = final.unstable.${name};
  }) codingAgentPkgs
))
