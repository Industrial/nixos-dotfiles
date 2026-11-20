# Drakkar storage layout

Declared in [`disko.nix`](./disko.nix) and [`filesystems.nix`](./filesystems.nix).

| Path | Device | Role |
| --- | --- | --- |
| `/boot` | `/dev/nvme0n1`, 512M ESP | bootloader |
| `/` `/nix` `/home` `/var` | `/dev/nvme0n1`, LUKS `cryptroot` → btrfs subvolumes `@root` `@nix` `@home` `@var` | OS, store, home |
| `/data` | `/dev/sda`, one btrfs filesystem, no subvolumes | local bulk storage (HDD) |
| `/data/cache` | created by `systemd.tmpfiles` | active repos, build trees, scratch |
| `/data/Games` | created by `systemd.tmpfiles` | local game root |

`/data` is scrubbed monthly (`services.btrfs.autoScrub`). It is not encrypted; only the
NVMe is.

## Conventions

- **Hot / active work** → `/data/cache/` (git clones, cargo targets, temp exports).
- **Games** → `/data/Games/`. Drakkar is the fleet's only game station; do not install games
  on mimir.
- **Shared / archive** → mimir's `/data/archive/`, copied by hand. Mimir is authoritative
  for archived data.

## Shared storage

Mimir's NFS export allows drakkar (`features/storage/nfs-server`), and drakkar imports
`features/storage/nfs-client`, which installs `nfs-utils` only. **Drakkar declares no
mount**, so `/mnt/mimir` does not exist until you mount it by hand:

```bash
sudo mkdir -p /mnt/mimir
sudo mount -t nfs4 mimir:/data /mnt/mimir
```

For a declarative mount, copy the `fileSystems."/mnt/mimir"` block from
[`../muninn/filesystems.nix`](../muninn/filesystems.nix).

## Builds

Drakkar is a remote builder for mimir (`features/fleet/nix-remote-builder-server.nix`);
see [`docs/runbooks/nix-remote-build.md`](../../docs/runbooks/nix-remote-build.md).
