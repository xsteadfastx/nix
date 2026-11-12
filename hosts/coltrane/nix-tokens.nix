# nix's own credentials, rendered from sops at activation instead of being
# hand-maintained in ~/.config/nix/netrc: the attic JWT for the substituter, and
# a gh token because the flake resolver calls api.github.com (60 req/h per IP
# unauthenticated, 5000 with a token).
#
# Both live in one netrc because both are the same thing to nix: per-host Basic
# auth, matched by *request* host. The github entry must therefore name
# `api.github.com`; `machine github.com` matches git only and leaves the
# resolver unauthenticated (measured on Lix 2.94.3). That is undocumented
# behaviour -- the alternative is `access-tokens` plus a second `!include`
# template. If a future nix stops honouring netrc for the resolver, the symptom
# is nothing worse than the old rate-limit warning returning.
#
# ponytail: the attic JWT also stays in ~/.config/attic/config.toml, because
# `attic` reads only that; `attic login` does not update this copy, so on
# rotation re-run `sops set hosts/coltrane/secrets.yaml attic-token …`.
#
# Home-manager module => marv's nix only. Root's `sudo nixos-rebuild` reads
# /etc/nix/nix.conf and stays unauthenticated.
{ config, lib, ... }:
{
  # The host file, not the default ../secrets.yaml: gh-token already lives there
  # for the system side, so no token is duplicated. The HM age key decrypts it.
  sops.secrets."gh-token".sopsFile = ./secrets.yaml;
  sops.secrets."attic-token".sopsFile = ./secrets.yaml;

  sops.templates."nix-netrc".content = ''
    machine attic.iot.wolfsburg.digital
      password ${config.sops.placeholder."attic-token"}
    machine api.github.com
      password ${config.sops.placeholder."gh-token"}
  '';

  # base.nix points netrc-file at the hand-written ~/.config/nix/netrc for the
  # other hosts, hence mkForce here.
  nix.settings.netrc-file = lib.mkForce config.sops.templates."nix-netrc".path;
}
