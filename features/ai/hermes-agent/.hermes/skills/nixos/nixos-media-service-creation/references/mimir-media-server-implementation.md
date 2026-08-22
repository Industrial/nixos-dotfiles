# Mimir Media Server Implementation Session (2026-08-21)

## Summary
Implemented a complete media server stack on Mimir with NFS-compatible storage and monitoring capabilities.

## Changes Made

### New Features Created
1. `features/media/homarr/default.nix` - Homarr dashboard service (port 7575)
2. `features/monitoring/prometheus-agent/default.nix` - Node exporter for all hosts

### Updated Features
- All media services (`jellyfin`, `lidarr`, `sonarr`, `radarr`, `prowlarr`, `qbittorrent`, `readarr`, `overseerr`, `jellyseerr`, `invidious`) updated to use `/data/services/${name}` for NFS compatibility
- `features/media/qbittorrent/default.nix` - Enhanced to headless version (qbittorrent-nox) with proper systemd service structure

### Host Configuration Updates
- `hosts/mimir/configuration.nix` - Added all media services + monitoring agent + Grafana imports
- `hosts/drakkar/configuration.nix` - Added monitoring agent import
- `hosts/huginn/configuration.nix` - Added monitoring agent import

### Removed Features
- `features/monitoring/homepage-dashboard/` (replaced with Homarr)
- `features/monitoring/uptime-kuma/` (per user request)

## Key Technical Details

### NFS Compatibility Critical Path
All services now use `/data/services/${servicename}` for persistent storage, which:
- Is exported via NFS from Mimar to Drakkar/Huginn (see `features/storage/nfs-server/default.nix`)
- Is accessible on Drakkar/Huginn at `/mnt/mimir/services/${servicename}`
- Ensures media files and service configs are available across all machines

### Service Structure Requirements
Learned and enforced these critical NixOS module patterns:
1. `tmpfiles` MUST be inside `systemd = {`, not at top level
2. `groups` MUST be inside `users = {`, not at top level
3. Correct service user/group setup with `extraGroups = ["data"]` for NFS access
4. Proper `Let ... in {}` structure with `directoryPath = "/data/services/${name}";`

### Verification Process
1. Syntax check: `nix eval --raw --json '(import ./module.nix {})'`
2. Fleet validation: `bin/fleet check mimir`
3. Build test: `nix build .#mimir.config.system.build.toplevel --keep-going`
4. Deployment: `bin/fleet deploy mimir --dry-activate` → `bin/fleet deploy mimir`

## Files Modified
- Created: `features/media/homarr/default.nix`
- Created: `features/monitoring/prometheus-agent/default.nix`
- Updated: All 10 media services in `features/media/` for NFS paths
- Updated: `features/media/qbittorrent/default.nix` (headless version + proper structure)
- Updated: `hosts/mimir/configuration.nix`
- Updated: `hosts/drakkar/configuration.nix`
- Updated: `hosts/huginn/configuration.nix`
- Removed: `features/monitoring/homepage-dashboard/` directory
- Removed: `features/monitoring/uptime-kuma/` directory

## Access Points Post-Deployment
- Homarr Dashboard: `http://[mimir-tailscale-ip]:7575`
- Grafana: `http://[mimir-tailscale-ip]:9000`
- Individual services accessible via Homarr links or direct ports (all via Tailscale)

## Next Steps
- Configure individual service credentials/UI as needed
- Consider adding alerting rules to Prometheus
- Document specific service configurations in individual service reference files