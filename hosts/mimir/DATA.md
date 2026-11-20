# Mimir storage layout

Declared in [`disko.nix`](./disko.nix) and [`filesystems.nix`](./filesystems.nix); the
install-time detail and the disk-failure procedure are in [`INSTALL.md`](./INSTALL.md).

| Path | Device | Role |
| --- | --- | --- |
| `/boot` | `/dev/nvme0n1`, 512M ESP | bootloader |
| `/` `/nix` | `/dev/nvme0n1`, LUKS `cryptroot` → btrfs subvolumes `@root` `@nix` | OS and store (`/home` and `/var` live inside `@root`) |
| `/data` | `LABEL=data`: one btrfs RAID5 volume over `/dev/sd[a-d]`, `compress=zstd,nofail` | fleet bulk storage (~55 TB usable), not encrypted |

`/data` is scrubbed monthly (`services.btrfs.autoScrub`).

```
/data/
  archive/   # cold storage; manual copies from the other hosts land here
  docker/    # persistent container volumes (docker is disabled on this host today)
  scratch/   # shared temporary files, mode 0777, safe to delete
  cache/     # optional shared cache (build artifacts, etc.)
```

The four directories come from `systemd.tmpfiles`. Because `/data` is `nofail`, they also
exist on the root filesystem when the array is not mounted: `ls /data` succeeding proves
nothing; `findmnt /data` does.

## Conventions

- **Mimir is authoritative for archived data.** Copy from other hosts into
  `/data/archive/` by hand; nothing syncs automatically.
- **Scratch is shared and disposable**: do not keep anything in `/data/scratch/` you would
  miss.

## NFS export

`features/storage/nfs-server` exports `/data` read-write (`rw,sync,no_subtree_check`) to
two Tailscale addresses, drakkar's and huginn's, and opens the NFS ports on `tailscale0`
only. `nfs-server.service` requires the `/data` mount, so NFS refuses to serve an empty
directory when the array is down.

Who mounts it today:

| Host | Mount |
| --- | --- |
| drakkar | none declared; mount by hand ([`../drakkar/DATA.md`](../drakkar/DATA.md)) |
| huginn | none declared; removed while mimir was down ([`../huginn/DATA.md`](../huginn/DATA.md)) |
| muninn | declares `/mnt/mimir`, but is **not** in the export list ([`../muninn/DATA.md`](../muninn/DATA.md)) |
