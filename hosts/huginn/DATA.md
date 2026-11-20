# Huginn storage layout

Declared in [`disko.nix`](./disko.nix). Huginn is a tablet with one NVMe and no bulk disk;
the layout and the reasons for its mount options are in [`INSTALL.md`](./INSTALL.md).

| Path | Device | Role |
| --- | --- | --- |
| `/boot` | `/dev/nvme0n1`, 512M ESP | bootloader |
| `/` `/nix` `/home` `/var` | `/dev/nvme0n1`, LUKS `cryptroot` → btrfs subvolumes `@root` `@nix` `@home` `@var`, `compress=zstd,noatime` | OS, store, home |
| `/swap` | subvolume `@swap`, `noatime` | 20G swapfile, the hibernation target |

There is no `/data`. Huginn is the smallest disk in the fleet: keep bulk data on mimir.

## Conventions

- **Active work** → `~` (compressed, on the NVMe). Build trees are cheap to throw away.
- **Anything to keep** → mimir's `/data/archive/`, copied by hand.
- **Never** put files under `/swap`; the swapfile must stay where hibernation recorded it.

## Shared storage

Mimir's NFS export allows huginn (`features/storage/nfs-server`), and huginn imports
`features/storage/nfs-client` (`nfs-utils` only). The declarative mount was removed while
mimir was down ([`filesystems.nix`](./filesystems.nix)), so mount by hand:

```bash
sudo mkdir -p /mnt/mimir
sudo mount -t nfs4 mimir:/data /mnt/mimir
```

To restore it, copy the `fileSystems."/mnt/mimir"` block from
[`../muninn/filesystems.nix`](../muninn/filesystems.nix).
