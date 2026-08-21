# Drakkar storage layout

| Path | Role |
|------|------|
| `/` `/nix` `/home` | 2 TB NVMe (LUKS btrfs) — OS and nix store |
| `/data` | 16 TB HDD btrfs — local bulk (legacy; migrate cold data to Mimir) |
| `/data/cache` | Active repos, build trees, scratch work (fast local HDD) |
| `/mnt/mimir` | NFS mount of Mimir `/data` — shared archive and fleet storage |

## Conventions

- **Hot / active work** → `/data/cache/` (git clones, cargo targets, temp exports)
- **Shared / archive** → `/mnt/mimir/archive/` (manual copy; Mimir is authoritative)
- **Local legacy** → `/data/` on HDD until you finish migrating to Mimir

Remote builds from Mimir/Huginn run on this machine (7950X) via `features/fleet/nix-remote-builder-server.nix`.
