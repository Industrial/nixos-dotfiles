# Service Deployment Plan for NixOS Fleet

## Host Roles Analysis
- **Drakkar**: Desktop workstation + Remote Nix builder (offloads builds for Mimir/Huginn via SSH)
- **Huginn**: Tablet device (mobile profile only, lightweight)
- **Mimir**: File server + NFS server (exports /data to Drakkar/Huginn via Tailscale)

## Key Discovery from Session
**CRITICAL FINDING**: All requested media and monitoring services already exist as 100% Nix-managed modules in `features/media/` and `features/monitoring/` - no JSON files or state management needed!

## Confirmed Service Distribution (Based on Session Findings)

### **Mimir (Primary Services Host)**
**Media Services** (all confirmed existing in `features/media/`):
- Jellyfin (media server)
- Lidarr (music manager)
- Sonarr (TV manager) 
- Radarr (movie manager)
- Prowlarr (indexer manager)
- **QBittorrent** - Use existing module but enhance for headless/no-x version
- Readarr (book manager)
- Overseerr (request management)
- Jellyseerr (Jellyfin request system)
- Invidious (YouTube frontend)

**Monitoring Services** (all confirmed existing in `features/monitoring/`):
- Prometheus server (port 9001) with node exporter (port 9002)
- Grafana (port 9000) 
- **Replace homepage-dashboard with Homarr** (need to create Homarr module)
- **Remove uptime-kuma** (as requested)

**Infrastructure**:
- Continue existing NFS server exports (/data to Drakkar/Huginn via Tailscale)

### **Drakkar**
- Prometheus Agent: Node exporter for monitoring
- Optional: Media consumption clients (Jellyfin client, qBittorrent web UI)
- Development work (primary dev machine)
- Remote Builder: Keep existing Nix remote builder role

### **Huginn**
- Prometheus Agent: Node exporter for monitoring
- Optional: Media consumption (Jellyfin client for tablet)
- Keep mobile profile minimal

## Important Notes from Session
- **Whisparr**: Marked as TODO in existing module - NOT available in nixpkgs, skip for now
- **QBittorrent**: Existing module is basic package install only - needs enhancement to match *arr pattern (systemd service, user, data directory)
- **Homarr**: Does NOT exist as feature - needs to be created (not in nixpkgs, will require custom module)
- All services use `/mnt/well/services/${servicename}` for persistent state (directory structure already exists)

## Implementation Phases (Updated Based on Session)

### Phase 1: Foundation & Monitoring
- **Create**: `features/monitoring/prometheus-agent/default.nix` (node exporter for all hosts)
- **Update**: `features/media/qbittorrent/default.nix` to enhance for headless version with proper systemd service
- **Create**: `features/media/homarr/default.nix` (Homarr service dashboard)
- Set up Grafana on Mimir with Prometheus datasource (already exists)
- Verify basic host metrics collection

### Phase 2: Storage & Media Infrastructure
- Verify Mimir has adequate storage mounted (check /data usage)
- Media directory structure in `/mnt/well/services/` already exists and ready
- Set up proper permissions for media services (already handled in existing modules)

### Phase 3: Service Deployment
**NO NEW MODULES NEEDED FOR MEDIA SERVICES** - they already exist!
- Add confirmed existing services to Mimir's configuration.nix imports:
  - ../../media/jellyfin/default.nix
  - ../../media/lidarr/default.nix  
  - ../../media/sonarr/default.nix
  - ../../media/radarr/default.nix
  - ../../media/prowlarr/default.nix
  - ../../media/qbittorrent/default.nix (enhanced version)
  - ../../media/readarr/default.nix
  - ../../media/overseerr/default.nix
  - ../../media/jellyseerr/default.nix
  - ../../media/invidious/default.nix
  - ../../media/homarr/default.nix (new)
  - ../../monitoring/prometheus/default.nix
  - ../../monitoring/grafana/default.nix
  - REMOVE: homepage-dashboard and uptime-kuma imports

### Phase 4: Networking & Access
- All services bind to 0.0.0.0 (already configured in existing modules)
- Accessible only via Tailscale (no WAN exposure needed)
- Existing operator SSH keys sufficient for fleet operations
- No additional firewall changes needed beyond existing Tailscale setup

### Phase 5: Dashboard & Integration
- Verify Homarr dashboard shows links to all services
- Confirm Grafana dashboards show host metrics from all three hosts
- Validate service health and accessibility

## Verification Steps (Updated)
- Run `nix flake check` after each module addition/update
- Test with `bin/fleet check mimir` before deployment
- Test service accessibility via Tailscale IPs
- Verify Grafana shows all host metrics (Mimir, Drakkar, Huginn)
- Confirm Homarr dashboard links work to all services
- Check `systemctl status` for each service on Mimir

## Key Considerations (Reinforced from Session)
- **All services accessible only via Tailscale** (no WAN exposure) - confirmed existing modules already follow this
- Use existing operator SSH keys for fleet operations
- Maintain separation of concerns: builder (Drakkar) vs. services (Mimir) vs. consumption (Huginn)
- Preserve existing NFS functionality while adding new services
- **MAXIMIZE NIX PURETY**: Leverage existing 100% Nix-managed modules, avoid JSON/state files
- **WHISPARR SKIP**: Not available in nixpkgs - do not attempt manual installation