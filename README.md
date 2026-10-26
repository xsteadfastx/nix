# nix — NixOS fleet

My NixOS configuration for five machines, following the **Coltrane** (columnar
Nix) pattern: each host is self-contained under `hosts/<name>/` and imports only
the shared modules it needs. There are no cross-host imports — adding a machine
means a new directory plus an entry in the colmena hive ([`hive.nix`](hive.nix)),
which is what `nixosConfigurations` is generated from.

## Layout

| Path | What |
| --- | --- |
| `flake.nix` | inputs, outputs, `nixosConfigurations`, dev shell |
| `hive.nix` | colmena hive (host list + deployment targets) |
| `hosts/<host>/` | one machine: `configuration.nix`, hardware, service modules, `secrets.nix` |
| `modules/` | reusable NixOS / Home Manager modules (`base`, `users`, `ssh`, `tlsrouter`, …) |
| `home-manager/` | per-user config (`marv.nix` + modules) |
| `overlays/` | the single central `pkgs.unstable` import plus package overrides |
| `pkgs/` | custom packages |
| `lib/` | per-host helpers the hive calls with that host's values (node exporter, the small Hetzner VM profile) |
| `docs/` | runbooks; design specs and plans under `docs/superpowers/` |
| `CLAUDE.md` | agent memory: architecture notes and hard-won workarounds |

## Hosts

| Host | Platform | Role |
| --- | --- | --- |
| `abed` | x86_64, Hetzner Cloud | Server: Forgejo, Caddy, Anubis, restic backups |
| `coltrane` | Dell XPS 13 | Daily driver laptop: pi coding agent + MCP servers, paperless, ollama, syncthing |
| `dipper` | x86_64, Hetzner Cloud | Matrix homeserver (tuwunel) and its bridges |
| `phil` | Raspberry Pi 3 | CUPS printer |
| `duemmel` | Raspberry Pi 4 (works on 3 B+ too) | C-ITS receiver: ESP32-C5 over USB → opentrafficmap.org |

## Documentation

| Doc | Covers |
| --- | --- |
| **[docs/matrix.md](docs/matrix.md)** | Matrix homeserver and bridges: architecture, adding a user, connecting a bridge, troubleshooting |
| [CLAUDE.md](CLAUDE.md) | Architecture decisions, known issues, workarounds |
| `docs/superpowers/` | Design specs and implementation plans |

## Commands

```sh
sudo nixos-rebuild switch      # build and activate on this host
nix flake check                # lint + pre-commit checks (the CI gate)
nix fmt                        # format; run before committing
nix flake update               # bump locked inputs (then rebuild)
```

Build a host without switching (no sudo needed — `marv` is in `trusted-users`):

```sh
nix build .#nixosConfigurations.dipper.config.system.build.toplevel \
  --no-link --print-out-paths
```

Remote hosts are deployed with colmena via the hive in `hive.nix`. The Pi
hosts (`phil`, `duemmel`) build on the target itself (`deployment.buildOnTarget`):
a deploy needs them reachable, and it fetches from cache.nixos.org instead of
cross-compiling from x86_64.

### Raspberry Pi SD images

Hosts that are flashed rather than deployed have an image builder wired up as a
flake package — `hosts/duemmel/sdcard-img.nix`, and `pkgs/phil-sdcard-img/` for
the older one:

```sh
nix build .#packages.x86_64-linux.duemmel-sdcard-img
zstd -d < result/sd-image/*.img.zst \
  | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

These are plain `sd-image-aarch64` builds (Pi 3/4; `duemmel` targets a Pi 4); a Pi 5 needs the
`nixos-hardware` raspberry-pi-5 module added to the image's module list.

`duemmel` reads its WiFi credentials from the FAT partition after flashing — the
image itself contains no secrets:

```sh
sudo mount /dev/sdX1 /mnt                        # the FIRMWARE (vfat) partition
printf 'ssid=myssid\npsk=mysecret\n' | sudo tee /mnt/wifi.conf
sudo umount /mnt
```

## Conventions

- **Secrets are sops-nix only.** Declare every secret in
  `hosts/<host>/secrets.nix`, keep the ciphertext in that host's `secrets.yaml`,
  and never hardcode a value. Edit with `sops hosts/<host>/secrets.yaml`.
  Exception: `duemmel` has no key at first boot, so its WiFi credentials live on
  the SD card's boot partition (see *Raspberry Pi SD images* above) instead of
  in a sops file that nothing could decrypt yet.
- **Conventional Commits** for every commit message (`feat:`, `fix:`, `docs:`, …).
- `nix flake check` runs the pre-commit hooks — there is no separate
  `pre-commit run` step.
- When a change alters observable behavior, update the doc that describes it in
  the same change.
