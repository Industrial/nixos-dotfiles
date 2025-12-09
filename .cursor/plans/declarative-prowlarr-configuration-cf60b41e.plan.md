<!-- cf60b41e-6ea3-4567-9b79-724d128f27ec 8ad2e47b-5d90-4ba7-8efa-2f1164139fda -->
# Declarative *Arr Services Configuration Plan (Buildarr)

## Overview

Transform all *Arr service configurations from runtime web UI management to fully declarative Nix-based configuration using Buildarr. This will enable reproducible, version-controlled configuration for all *Arr application settings including indexers, download clients, quality profiles, media management, and sync settings.

## *Arr Services in Codebase

The following *Arr services are currently available:

1. **Prowlarr** (port 9696) - Indexer manager - ✅ Buildarr supported
2. **Sonarr** (port 8989) - TV show manager - ✅ Buildarr supported
3. **Radarr** (port 7878) - Movie manager - ✅ Buildarr supported
4. **Lidarr** (port 8686) - Music manager - ✅ Buildarr supported
5. **Readarr** (port 8787) - Book manager - ✅ Buildarr supported
6. **Whisparr** (port 6969) - Adult content manager - ❌ Not supported by Buildarr
7. **Jellyseerr** (port 5055) - Media request management - ✅ Buildarr supported
8. **Overseerr** (port 5055) - Media request management - ❌ Not supported by Buildarr

**Note:** Bazarr (subtitle manager) is not currently in the codebase but can be added if needed (✅ Buildarr supported).

## Buildarr Support Matrix

| Service | Buildarr Support | Configuration Scope |
|---------|-----------------|---------------------|
| Prowlarr | ✅ Full support | Indexers, download clients, sync settings, application settings |
| Sonarr | ✅ Full support | Quality profiles, media management, import lists, indexers, download clients, sync |
| Radarr | ✅ Full support | Quality profiles, media management, import lists, indexers, download clients, sync |
| Lidarr | ✅ Full support | Quality profiles, media management, import lists, indexers, download clients, sync |
| Readarr | ✅ Full support | Quality profiles, media management, import lists, indexers, download clients, sync |
| Whisparr | ❌ Not supported | Keep manual configuration |
| Jellyseerr | ✅ Full support | Application settings, Sonarr/Radarr integration |
| Overseerr | ❌ Not supported | Keep manual configuration |

## Architecture

- Keep current *Arr systemd service setups (all follow same pattern)
- Add Buildarr as a systemd service that manages all *Arr configurations
- Store Buildarr configuration in Nix (generate YAML from Nix expressions)
- Buildarr connects to each *Arr API and applies configuration declaratively
- Single Buildarr instance manages all *Arr services
- Service dependencies: Buildarr → Prowlarr → (Sonarr/Radarr/Lidarr/Readarr)

## Implementation Phases

### Phase 1: Buildarr Infrastructure Setup (2-3 days)

1. **Create Buildarr Feature Module**

- Location: `features/media/buildarr/default.nix`
- Install Buildarr package (via pip or nixpkgs)
- Create systemd service for Buildarr daemon
- Set up configuration directory: `/mnt/well/services/buildarr/`
- Configure Buildarr to watch config file and run on schedule
- Set up logging and error handling

2. **Design Unified Configuration Structure**

- Location: `features/media/buildarr/config.nix` (new file)
- Create shared Nix module for Buildarr configuration
- Design Nix types for all *Arr service configurations
- Create YAML generator function using `pkgs.formats.yaml` or `pkgs.writeText`
- Implement API key management (use sops-nix or agenix)

### Phase 2: Service-Specific Configuration Modules (3-4 days)

3. **Prowlarr Configuration Module**

- Location: `features/media/prowlarr/config.nix` (new file)
- Define Nix options for:
 - Indexers (list with name, url, apiKey, categories, etc.)
 - Download clients (qBittorrent, Transmission, etc.)
 - Application settings (port, SSL, authentication, UI settings)
 - Sync settings (Sonarr, Radarr, Lidarr, Readarr integration)
- Generate Buildarr YAML configuration section

4. **Sonarr Configuration Module**

- Location: `features/media/sonarr/config.nix` (new file)
- Define Nix options for:
 - Quality profiles (definitions with quality groups, custom formats)
 - Media management (root folders, file naming, import/export settings)
 - Indexers (from Prowlarr sync or manual)
 - Download clients (qBittorrent, etc.)
 - Import lists (Plex, Trakt, etc.)
 - Application settings (general, UI, security)

5. **Radarr Configuration Module**

- Location: `features/media/radarr/config.nix` (new file)
- Define Nix options for:
 - Quality profiles (definitions with quality groups, custom formats)
 - Media management (root folders, file naming, import/export settings)
 - Indexers (from Prowlarr sync or manual)
 - Download clients (qBittorrent, etc.)
 - Import lists (Plex, Trakt, etc.)
 - Application settings (general, UI, security)

6. **Lidarr Configuration Module**

- Location: `features/media/lidarr/config.nix` (new file)
- Define Nix options for:
 - Quality profiles (definitions with quality groups, custom formats)
 - Media management (root folders, file naming, import/export settings)
 - Indexers (from Prowlarr sync or manual)
 - Download clients (qBittorrent, etc.)
 - Import lists (Last.fm, Spotify, etc.)
 - Application settings (general, UI, security)

7. **Readarr Configuration Module**

- Location: `features/media/readarr/config.nix` (new file)
- Define Nix options for:
 - Quality profiles (definitions with quality groups, custom formats)
 - Media management (root folders, file naming, import/export settings)
 - Indexers (from Prowlarr sync or manual)
 - Download clients (qBittorrent, etc.)
 - Import lists (Goodreads, etc.)
 - Application settings (general, UI, security)

8. **Jellyseerr Configuration Module**

- Location: `features/media/jellyseerr/config.nix` (new file)
- Define Nix options for:
 - Sonarr/Radarr integration (API keys, URLs)
 - Application settings (general, notifications, UI)
 - User management (if supported by Buildarr)

### Phase 3: Service Module Updates (2-3 days)

9. **Update Each *Arr Service Module**

- For each service (prowlarr, sonarr, radarr, lidarr, readarr):
 - Update `features/media/{service}/default.nix`
 - Add import for config module
 - Add configuration options
 - Keep existing systemd service setup (no changes needed)
 - Add Buildarr dependency (service should start after Buildarr applies config)

10. **Update Jellyseerr Module**

 - Update `features/media/jellyseerr/default.nix`
 - Add Buildarr configuration integration
 - Keep NixOS native service (already using `services.jellyseerr`)

### Phase 4: Integration & Migration (3-4 days)

11. **Create Unified Buildarr Configuration Generator**

 - Location: `features/media/buildarr/generate-config.nix` (new file)
 - Combine all service configurations into single Buildarr YAML
 - Handle service dependencies (Prowlarr must be configured before others)
 - Generate complete `buildarr.yml` file

12. **Update Mimir Host Configuration**

 - Location: `hosts/mimir/flake.nix`
 - Enable Buildarr feature module
 - Enable all *Arr services with declarative config
 - Configure each service's settings in Nix
 - Add service dependencies (Buildarr → Prowlarr → Sonarr/Radarr/etc.)

13. **Export Current Configurations**

 - For each running *Arr service:
 - Use `buildarr {service} dump-config` to export current state
 - Convert exported YAML to Nix configuration format
 - Verify all settings are captured correctly

14. **Test Configuration Application**

 - Test Buildarr applying configurations to each service
 - Verify idempotency (running multiple times produces no changes)
 - Test configuration updates (modify Nix, rebuild, verify changes applied)
 - Test service dependencies (Prowlarr sync to Sonarr/Radarr)

### Phase 5: Documentation & Polish (1-2 days)

15. **Documentation**

 - Document configuration options for each service
 - Create examples for common scenarios
 - Document migration process
 - Update README with new declarative approach

16. **Handle Unsupported Services**

 - Whisparr: Document that it's not supported by Buildarr, keep manual configuration
 - Overseerr: Document that it's not supported by Buildarr, keep manual configuration
 - Consider alternatives or manual API-based configuration if needed

## Service Configuration Details

### Prowlarr Configuration Changes

**Current:** Only systemd service, no application configuration
**New:** Full declarative configuration via Buildarr

Key settings to configure:

- Indexers (name, url, apiKey, categories, priority)
- Download clients (qBittorrent, Transmission, etc.)
- Application settings (port, SSL, authentication, UI)
- Sync settings (Sonarr, Radarr, Lidarr, Readarr integration)

### Sonarr Configuration Changes

**Current:** Only systemd service, no application configuration
**New:** Full declarative configuration via Buildarr

Key settings to configure:

- Quality profiles (definitions, upgrade paths, custom formats)
- Media management (root folders, file naming, import/export)
- Indexers (sync from Prowlarr or manual)
- Download clients (qBittorrent, etc.)
- Import lists (Plex, Trakt, etc.)
- Application settings (general, UI, security)

### Radarr Configuration Changes

**Current:** Only systemd service, no application configuration
**New:** Full declarative configuration via Buildarr

Key settings to configure:

- Quality profiles (definitions, upgrade paths, custom formats)
- Media management (root folders, file naming, import/export)
- Indexers (sync from Prowlarr or manual)
- Download clients (qBittorrent, etc.)
- Import lists (Plex, Trakt, etc.)
- Application settings (general, UI, security)

### Lidarr Configuration Changes

**Current:** Only systemd service, no application configuration
**New:** Full declarative configuration via Buildarr

Key settings to configure:

- Quality profiles (definitions, upgrade paths, custom formats)
- Media management (root folders, file naming, import/export)
- Indexers (sync from Prowlarr or manual)
- Download clients (qBittorrent, etc.)
- Import lists (Last.fm, Spotify, etc.)
- Application settings (general, UI, security)

### Readarr Configuration Changes

**Current:** Only systemd service, no application configuration
**New:** Full declarative configuration via Buildarr

Key settings to configure:

- Quality profiles (definitions, upgrade paths, custom formats)
- Media management (root folders, file naming, import/export)
- Indexers (sync from Prowlarr or manual)
- Download clients (qBittorrent, etc.)
- Import lists (Goodreads, etc.)
- Application settings (general, UI, security)

### Jellyseerr Configuration Changes

**Current:** Uses NixOS native service, no application configuration
**New:** Full declarative configuration via Buildarr

Key settings to configure:

- Sonarr integration (API key, URL, instance name)
- Radarr integration (API key, URL, instance name)
- Application settings (port, base URL, notifications, UI)

### Whisparr & Overseerr

**Status:** Not supported by Buildarr
**Action:** Keep current manual configuration approach, document limitation

## Files to Create/Modify

### New Files

- `features/media/buildarr/default.nix` - Buildarr service module
- `features/media/buildarr/config.nix` - Unified Buildarr configuration
- `features/media/buildarr/generate-config.nix` - YAML generator
- `features/media/prowlarr/config.nix` - Prowlarr declarative configuration
- `features/media/sonarr/config.nix` - Sonarr declarative configuration
- `features/media/radarr/config.nix` - Radarr declarative configuration
- `features/media/lidarr/config.nix` - Lidarr declarative configuration
- `features/media/readarr/config.nix` - Readarr declarative configuration
- `features/media/jellyseerr/config.nix` - Jellyseerr declarative configuration

### Modified Files

- `features/media/prowlarr/default.nix` - Add configuration options
- `features/media/sonarr/default.nix` - Add configuration options
- `features/media/radarr/default.nix` - Add configuration options
- `features/media/lidarr/default.nix` - Add configuration options
- `features/media/readarr/default.nix` - Add configuration options
- `features/media/jellyseerr/default.nix` - Add configuration options
- `hosts/mimir/flake.nix` - Enable all services with declarative config

## Success Criteria

- All supported *Arr settings managed in Nix configuration
- Configuration changes applied automatically via Buildarr
- No manual web UI configuration required for supported services
- Configuration is version-controlled and reproducible
- Service dependencies properly handled (Prowlarr → others)
- Idempotent configuration application
- Ready to extend to additional *Arr applications

## Risks & Considerations

- **API Key Management:** Need secure storage for all *Arr API keys (sops-nix/agenix)
- **Migration Complexity:** Exporting existing configs may be complex
- **Buildarr Maintenance:** External dependency that needs updates
- **Configuration Drift:** Need to ensure Buildarr keeps config in sync
- **Service Dependencies:** Must ensure proper startup order
- **Unsupported Services:** Whisparr and Overseerr remain manual

## Timeline Estimate

- Phase 1: 2-3 days
- Phase 2: 3-4 days
- Phase 3: 2-3 days
- Phase 4: 3-4 days
- Phase 5: 1-2 days
**Total: 11-16 days**

### To-dos

- [ ] Create Buildarr feature module with systemd service (features/media/buildarr/default.nix)
- [ ] Design unified Buildarr configuration structure (features/media/buildarr/config.nix)
- [ ] Create Prowlarr configuration module with Nix options (features/media/prowlarr/config.nix)
- [ ] Create Sonarr configuration module with Nix options (features/media/sonarr/config.nix)
- [ ] Create Radarr configuration module with Nix options (features/media/radarr/config.nix)
- [ ] Create Lidarr configuration module with Nix options (features/media/lidarr/config.nix)
- [ ] Create Readarr configuration module with Nix options (features/media/readarr/config.nix)
- [ ] Create Jellyseerr configuration module with Nix options (features/media/jellyseerr/config.nix)
- [ ] Update all *Arr service modules to integrate configuration options
- [ ] Create unified Buildarr YAML generator (features/media/buildarr/generate-config.nix)
- [ ] Update mimir host configuration to enable all services with declarative config
- [ ] Export current configurations from running services using Buildarr dump-config
- [ ] Test configuration application, idempotency, and service dependencies
- [ ] Document configuration options, create examples, and update README