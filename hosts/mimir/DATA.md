# Mimir /data layout

Bulk storage lives on the RAID5 btrfs mount at `/data` (~55 TB usable).

```
/data/
  archive/   # cold storage — manual imports from Drakkar land here
  docker/    # persistent container volumes
  scratch/   # shared temporary files (safe to delete)
  cache/     # optional shared cache (build artifacts, etc.)
```

NFS export: `/data` is exported read-write to Drakkar and Huginn over Tailscale.
Clients mount at `/mnt/mimir`.

**Data migration from Drakkar is manual** — copy when ready, e.g. to `/mnt/mimir/archive/` from Drakkar.
