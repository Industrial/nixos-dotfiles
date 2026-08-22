---
id: nixos-fleet-management
name: NixOS Fleet Management
description: >-
  Manage Drakkar/Huginn/Mimir via unified flake + deploy-rs. Prefer
  nixos-deploy-rs and nixos-managing skills. Hermes-specific SSH/wrappers are
  out of scope for the multi-host-deploy-rs mission.
---

# NixOS Fleet Management

**Canonical skills:** `nixos-deploy-rs`, `nixos-managing`

**Mission:** `.maestro/specs/multi-host-deploy-rs.md`

## Do\n\n1. Use root flake `deploy.nodes` + `deploy .#<host>`\n2. Keep per-host Disko/hardware under `hosts/<name>/`\n3. Disable comin while push-deploy is primary\n4. Operator SSH via `~/.ssh/config` — not `~/.hermes/`\n5. **When planning services, FIRST check `features/media/` and `features/monitoring/` for existing, fully Nix-managed modules before creating new ones**\n6. Refer to `references/service-deployment-plan.md` for detailed service distribution and implementation phases\n7. Update related runbooks in `docs/runbooks/` when adding new services\n8. Use the media service deployment plan template for consistent service implementation\n\n## Do not\n\n- Install Hermes-only deploy keys or `~/.hermes/bin/nixos-mgmt`\n- Activate with Colmena and deploy-rs on the same generation stream\n- Invent `colmena rollback` / `colmena update` subcommands\n- Expose services to WAN — keep all services Tailscale-only unless absolutely necessary

## Do not

- Install Hermes-only deploy keys or `~/.hermes/bin/nixos-mgmt`
- Activate with Colmena and deploy-rs on the same generation stream
- Invent `colmena rollback` / `colmena update` subcommands
- Expose services to WAN — keep all services Tailscale-only unless absolutely necessary

## Service Deployment Planning

When planning to add services to your NixOS fleet, follow this structured approach:

### 1. Foundation Analysis
- Review existing host configurations (`hosts/*/configuration.nix`)
- **CRITICAL**: Check `features/media/` and `features/monitoring/` for existing, fully Nix-managed services before creating new modules
- Understand current roles: \n  - Drakkar: Desktop workstation + Remote Nix builder\n  - Huginn: Tablet device (mobile profile)\n  - Mimir: File server + NFS server (exports /data)\n- Consult existing runbooks (`docs/runbooks/*.md`) for deployment patterns\n- Check available storage and resources on target hosts

## Service Assignment Strategy
## Service Assignment Strategy\\n**Key Discovery**: All media and monitoring services are already available as NixOS modules in `features/media/` and `features/monitoring/` - no JSON files or external state management needed!\\\\n\\\\n**Critical Learning**: Always check existing features first before creating new modules. In this session, all requested services (jellyfin, lidarr, sonarr, radarr, prowlarr, qbittorrent, readarr, seerr, jellyseerr, invidious, calibre, spotify, vlc, whisparr, prometheus, grafana, homarr) were already available as fully Nix-managed modules - only the seerr module needed correction from the overseerr rename, and qbittorrent needed enhancement to headless version.\\\\n\\\\nAssign services based on host capabilities:\\\\n- **Primary Services Host (Mimir)**: \\\\n  - Media servers: jellyfin, invidious\\\\n  - Download clients: qbittorrent-nox (headless)\\\\n  - Media management: lidarr, sonarr, radarr, prowlarr, readarr, seerr (formerly overseerr), jellyseerr\\\\n  - Monitoring stack: prometheus server, grafana, homarr (replaces homepage-dashboard)\\\\n  - Continue existing roles (NFS server)\\\\n  \\\\n- **Monitoring Agents (All hosts)**:\\\\n  - Prometheus node exporter (via monitoring agent)\\\\n  \\\\n- **Secondary Hosts (Drakkar)**:\\\\n  - Optional: Media consumption clients\\\\n  - Development work\\\\n  - Keep existing remote builder role\\\\n  \\\\n- **Lightweight Hosts (Huginn)**:\\\\n  - Optional: Media consumption apps\\\\n  - Keep mobile profile minimal\\\\n\\\\n**Critical Path**: All services requiring persistent storage MUST use `/data/services/${name}` as their data directory to ensure NFS accessibility from Drakkar and Huginn. Never use `/mnt/well` or other non-exported paths for service data that needs to be accessible across hosts.\\\\n\\\\n**Key Verification**: After updating any service module, always run `nix flake check` and `bin/fleet check <host>` to verify the configuration is valid before deployment.

**Reference**: See `templates/media-service-deployment-plan.md` for a complete deployment checklist and phase-by-phase implementation guide.

### 3. Implementation Phases
Deploy services in logical phases:
1. **Foundation & Monitoring**: Set up Prometheus agents on all hosts, Grafana on Mimir
2. **Storage & Media Infrastructure**: Prepare directory structure, set permissions
3. **Service Deployment**: Deploy media and management services to Mimir
4. **Networking & Access**: Configure firewall, reverse proxy, service authentication
5. **Dashboard & Integration**: Set up service dashboard and Grafana dashboards

### 4. Verification Steps
- Run `nix flake check` after each module addition
- Test with `bin/fleet check <host>` before deployment
- Verify service accessibility via Tailscale IPs
- Confirm Grafana shows all host metrics
- Test service dashboard links

### 5. Key Considerations
- All services should be accessible only via Tailscale (no WAN exposure)
- Use existing operator SSH keys for fleet operations
- Maintain separation of concerns: builder (Drakkar) vs. services (Mimir) vs. consumption (Huginn)
- Preserve existing NFS functionality while adding new services
- **Critical**: For services needing data persistence and NFS access, use `/data/services/${name}` as the data directory (not `/mnt/well` or other paths) to ensure availability on Drakkar and Huginn via NFS
