# Muninn storage layout

Declared in [`disko.nix`](./disko.nix) and [`filesystems.nix`](./filesystems.nix). One NVMe,
no bulk disk, no swap.

| Path | Device | Role |
| --- | --- | --- |
| `/boot` | `/dev/nvme0n1`, 512M ESP | bootloader |
| `/` `/nix` `/home` `/var` | `/dev/nvme0n1`, LUKS `cryptroot` → btrfs subvolumes `@root` `@nix` `@home` `@var` | OS, store, home |
| `/mnt/mimir` | NFS4 `mimir:/data`, `x-systemd.automount,nofail` | mimir's bulk storage, mounted on first access |

`/var` holds the standby monitoring state: Prometheus and Grafana run here as well as on
mimir (`features/monitoring/prometheus`, `features/monitoring/grafana`).

## Conventions

- **Active work** → `~` on the NVMe.
- **Anything to keep** → mimir's `/data/archive/`.

## Shared storage

Muninn is the only host that declares the `/mnt/mimir` mount. **Mimir's export list does
not include muninn**: `clientHosts` in `features/storage/nfs-server` names drakkar and
huginn only, so the server does not export `/data` to muninn's tailnet address. Because the
mount is `nofail` and automounted, this shows up as an empty or failing `/mnt/mimir`, not a
boot failure. Adding muninn's Tailscale IPv4 to `clientHosts` is what makes it work.
