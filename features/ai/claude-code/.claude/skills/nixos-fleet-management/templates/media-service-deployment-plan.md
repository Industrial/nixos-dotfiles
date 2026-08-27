# Media Service Deployment Plan for NixOS Fleet

## Discovery: Existing Nix-Managed Media Stack
All media services are already available as fully NixOS-managed modules in `features/media/`:
- jellyfin, lidarr, sonarr, radarr, prowlarr, qbittorrent, readarr, overseerr, jellyseerr
- invidious, calibre, spotify, vlc
- monitoring: prometheus, grafana, homepage-dashboard
- All use `/data/services/${servicename}` for persistent state (NFS-exported)
- No JSON files or external state management required

## Prerequisites Check
Before deployment:
1. [ ] Verify `/data/services` exists and has adequate space
2. [ ] Confirm Tailscale mesh is operational between all hosts
3. [ ] Check `nix flake check` passes
4. [ ] Review current host roles:
   - Drakkar: Desktop + Remote Nix builder
   - Huginn: Tablet (mobile)
   - Mimir: File server + NFS server

## Deployment Phases

### Phase 1: Foundation & Monitoring (All Hosts)
```bash
# Add monitoring agent to all hosts
# In each host's configuration.nix imports:
#   ../../monitoring/prometheus-agent/default.nix
#
# Verify: nix flake check && bin/fleet check <host>
```

### Phase 2: Core Services (Mimir Only)
```bash
# Add media and monitoring stack to mimir/configuration.nix imports:
#   ../../media/jellyfin/default.nix
#   ../../media/lidarr/default.nix
#   ../../media/sonarr/default.nix
#   ../../media/radarr/default.nix
#   ../../media/prowlarr/default.nix
#   ../../media/qbittorrent/default.nix
#   ../../media/readarr/default.nix
#   ../../media/seerr/default.nix
#   ../../media/jellyseerr/default.nix
#   ../../media/invidious/default.nix
#   ../../monitoring/prometheus/default.nix
#   ../../monitoring/grafana/default.nix
#   ../../monitoring/homepage-dashboard/default.nix
#
# Verify: nix flake check && bin/fleet check mimir
```

### Phase 3: Deployment & Verification
```bash
# Dry-run first
bin/fleet deploy mimir --dry-activate

# Actual deployment
bin/fleet deploy mimir

# Verify services:
#   systemctl status jellyfin lidarr sonarr radarr prowlarr qbittorrent prometheus grafana homepage-dashboard
#   Check Tailscale IP: http://[mimir-tailscale-ip]:8080 (Homepage dashboard)
#   Check Grafana: http://[mimir-tailscale-ip]:9000
```

## Service Access Matrix
All services accessible via Tailscale only:
- Jellyfin: http://[mimir-ip]:8096
- Lidarr: http://[mimir-ip]:8686
- Sonarr: http://[mimir-ip]:8989
- Radarr: http://[mimir-ip]:7878
- Prowlarr: http://[mimir-ip]:9696
- Overseerr/Jellyseerr: http://[mimir-ip]:5055
- Invidious: http://[mimir-ip]:4000
- Homepage Dashboard: http://[mimir-ip]:8080
- Grafana: http://[mimir-ip]:9000
- Prometheus: http://[mimir-ip]:9001

## Maintenance
- All services update via `nixos-rebuild switch --flake .#mimir`
- Configuration changes made in Nix modules, not service UIs
- Persistent data preserved in `/data/services/${servicename}/` (NFS-exported)