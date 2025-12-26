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

## Secrets Management

### Overview

Secrets management uses **agenix** with SSH host keys for encryption. This provides:
- Declarative secret management integrated with NixOS
- Host-specific encryption (each host can only decrypt its own secrets)
- Service-specific secret organization
- Secure storage of API keys, passwords, and credentials

### Tool Selection: Agenix

**Rationale:**
- Pure NixOS environment (no cloud KMS needed)
- Leverages existing SSH host keys infrastructure
- Simpler setup and maintenance than sops-nix
- Native NixOS integration with declarative configuration
- Each host decrypts only its own secrets (using SSH host keys)

### Secret Structure & Naming Convention

**Directory Structure:**
```
secrets/
├── .gitignore                 # Ignore unencrypted secret files
├── secrets.nix                # Agenix secrets definition (lists all secrets per host)
└── services/                  # Service-specific secret files
    ├── buildarr/
    │   ├── prowlarr-api-key.age
    │   ├── sonarr-api-key.age
    │   ├── radarr-api-key.age
    │   ├── lidarr-api-key.age
    │   ├── readarr-api-key.age
    │   └── jellyseerr-api-key.age
    ├── prowlarr/
    │   ├── indexer-*.age      # One file per indexer with API keys
    │   └── download-client-*.age
    ├── sonarr/
    │   ├── import-list-*.age  # Import list API keys (Plex, Trakt, etc.)
    │   └── download-client-*.age
    ├── radarr/
    │   ├── import-list-*.age
    │   └── download-client-*.age
    ├── lidarr/
    │   ├── import-list-*.age
    │   └── download-client-*.age
    ├── readarr/
    │   ├── import-list-*.age
    │   └── download-client-*.age
    └── jellyseerr/
        └── (secrets managed via Buildarr config)
```

**Naming Convention:**
- Format: `<service>/<purpose>-<identifier>.age`
- Examples:
  - `buildarr/prowlarr-api-key.age`
  - `prowlarr/indexer-rarbg.age`
  - `sonarr/import-list-plex.age`
  - `radarr/download-client-qbittorrent.age`

**Secret File Format:**
- Each `.age` file contains a single secret value (plain text, encrypted)
- No structured format needed (just the raw secret value)
- Multiple related secrets can be stored in separate files

### Agenix Configuration

**1. Secrets Definition File: `secrets/secrets.nix`**

This file defines which secrets exist and which hosts can decrypt them:

```nix
let
  # Import host public keys
  # These should be added to the repository after first system build
  mimir = "ssh-ed25519 AAAAC3... mimir";
  # Add other hosts as needed: huginn, drakkar, etc.
in
{
  # Buildarr API keys (mimir host only)
  "services/buildarr/prowlarr-api-key.age".publicKeys = [mimir];
  "services/buildarr/sonarr-api-key.age".publicKeys = [mimir];
  "services/buildarr/radarr-api-key.age".publicKeys = [mimir];
  "services/buildarr/lidarr-api-key.age".publicKeys = [mimir];
  "services/buildarr/readarr-api-key.age".publicKeys = [mimir];
  "services/buildarr/jellyseerr-api-key.age".publicKeys = [mimir];
  
  # Service-specific secrets (mimir host only, for now)
  "services/prowlarr/indexer-rarbg.age".publicKeys = [mimir];
  "services/sonarr/import-list-plex.age".publicKeys = [mimir];
  # ... add more as needed
}
```

**2. Adding Agenix to Flake**

Add agenix input to `hosts/mimir/flake.nix` (and other hosts as needed):

```nix
inputs = {
  agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # ... other inputs
};

# In modules list:
modules = [
  inputs.agenix.nixosModules.age
  # ... other modules
];
```

**3. Secret Decryption in Nix Configuration**

In Buildarr config modules, reference decrypted secrets:

```nix
# features/media/buildarr/config.nix
{ config, ... }: {
  # Reference agenix secrets
  age.secrets."buildarr/prowlarr-api-key" = {
    file = ../../../../secrets/services/buildarr/prowlarr-api-key.age;
    owner = "buildarr";
    group = "buildarr";
    mode = "0400";
  };
  
  # In YAML generation, read from secret file path
  # config.age.secrets."buildarr/prowlarr-api-key".path
}
```

### Access Control & Permissions

**1. Buildarr Service User**
- Create dedicated system user: `buildarr`
- User ID: Auto-assigned by NixOS
- Group: `buildarr`
- Home directory: Not needed (service user)
- Shell: `/run/current-system/sw/bin/nologin`

**2. Secret File Permissions**
- Owner: `buildarr` (or root, depending on service requirements)
- Group: `buildarr`
- Mode: `0400` (read-only for owner)
- Location: `/run/secrets/` (agenix default, or custom path)

**3. Buildarr Configuration File Permissions**
- Owner: `buildarr`
- Group: `buildarr`
- Mode: `0600` (read/write for owner)
- Location: `/mnt/well/services/buildarr/buildarr.yml`

**4. Host Access Control**
- Each host can only decrypt secrets listed in `secrets.nix` with its public key
- No cross-host secret decryption (each host isolated)
- Secrets are encrypted at rest in git repository
- Only decrypted on target host during NixOS evaluation

### Secret Integration into Buildarr Config

**Flow:**
1. Agenix decrypts secrets during NixOS evaluation
2. Secrets are available at `/run/secrets/<secret-name>` (or configured path)
3. Buildarr config generator reads secret files during YAML generation
4. Secret values are injected into Buildarr YAML configuration
5. Buildarr service reads YAML and uses secrets to connect to *Arr APIs

**Implementation Pattern:**
```nix
# In generate-config.nix
let
  # Read secrets from agenix paths
  prowlarrApiKey = builtins.readFile config.age.secrets."buildarr/prowlarr-api-key".path;
  sonarrApiKey = builtins.readFile config.age.secrets."buildarr/sonarr-api-key".path;
  
  # Build Buildarr YAML with secrets
  buildarrYaml = {
    prowlarr = {
      hostname = "localhost";
      port = 9696;
      api_key = prowlarrApiKey;
    };
    sonarr = {
      hostname = "localhost";
      port = 8989;
      api_key = sonarrApiKey;
    };
  };
in
  # Generate YAML file
```

### Adding/Updating Secrets

**Workflow:**

1. **Create new secret file:**
   ```bash
   # Edit unencrypted secret file
   vim secrets/services/prowlarr/indexer-newindexer.age
   # Add the secret value (plain text)
   ```

2. **Add to secrets.nix:**
   ```nix
   "services/prowlarr/indexer-newindexer.age".publicKeys = [mimir];
   ```

3. **Encrypt the secret:**
   ```bash
   cd secrets
   agenix -e services/prowlarr/indexer-newindexer.age
   ```

4. **Reference in Nix config:**
   ```nix
   age.secrets."prowlarr/indexer-newindexer" = {
     file = ../../../../secrets/services/prowlarr/indexer-newindexer.age;
     owner = "buildarr";
     mode = "0400";
   };
   ```

5. **Use in configuration:**
   ```nix
   let
     indexerApiKey = builtins.readFile config.age.secrets."prowlarr/indexer-newindexer".path;
   in
     # Use in Buildarr config
   ```

**Updating existing secrets:**
1. Decrypt: `agenix -d services/prowlarr/indexer-rarbg.age`
2. Edit the decrypted file
3. Re-encrypt: `agenix -e services/prowlarr/indexer-rarbg.age`
4. Commit encrypted file

### Files to Create

**New Secret Management Files:**
- `secrets/.gitignore` - Ignore unencrypted `.age` files (only commit encrypted)
- `secrets/secrets.nix` - Agenix secrets definition
- `secrets/services/buildarr/*.age` - Buildarr API keys (encrypted)
- `secrets/services/prowlarr/*.age` - Prowlarr secrets (encrypted)
- `secrets/services/sonarr/*.age` - Sonarr secrets (encrypted)
- `secrets/services/radarr/*.age` - Radarr secrets (encrypted)
- `secrets/services/lidarr/*.age` - Lidarr secrets (encrypted)
- `secrets/services/readarr/*.age` - Readarr secrets (encrypted)
- `features/media/buildarr/secrets.nix` - Secret references in Buildarr module

**Modified Files:**
- `hosts/mimir/flake.nix` - Add agenix input and module
- `features/media/buildarr/default.nix` - Create buildarr user, reference secrets
- `features/media/buildarr/config.nix` - Integrate secret reading
- `features/media/buildarr/generate-config.nix` - Inject secrets into YAML

### Security Considerations

- **No key rotation** for now (as per requirements)
- Secrets encrypted at rest in git repository
- Each host can only decrypt its own secrets (SSH host key isolation)
- Buildarr user has minimal permissions (only access to its secrets)
- Secret files have restrictive permissions (0400)
- Buildarr config file permissions (0600) prevent other users from reading
- No secrets in plain text in Nix expressions (all via file reads)

### Future Extensibility

This secrets management structure supports:
- Adding secrets for other services (Jellyfin, databases, etc.)
- Multi-host secret sharing (add multiple public keys to secrets.nix)
- Service-specific secret organization (clear directory structure)
- Easy secret updates (decrypt, edit, re-encrypt workflow)

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
- Integrate agenix secret management (see Secrets Management section)

3. **Set Up Agenix Infrastructure**

- Add agenix input to `hosts/mimir/flake.nix`
- Obtain SSH host public key from mimir host: `cat /etc/ssh/ssh_host_ed25519_key.pub`
- Create `secrets/secrets.nix` file defining all secrets with mimir host public key
- Set up secret directory structure (`secrets/services/`)
- Configure `secrets/.gitignore` for unencrypted secret files (commit only `.age` files)
- Document secret creation/update workflow

### Phase 2: Service-Specific Configuration Modules (3-4 days)

4. **Prowlarr Configuration Module**

- Location: `features/media/prowlarr/config.nix` (new file)
- Define Nix options for:
- Indexers (list with name, url, apiKey, categories, etc.)
- Download clients (qBittorrent, Transmission, etc.)
- Application settings (port, SSL, authentication, UI settings)
- Sync settings (Sonarr, Radarr, Lidarr, Readarr integration)
- Generate Buildarr YAML configuration section

5. **Sonarr Configuration Module**

- Location: `features/media/sonarr/config.nix` (new file)
- Define Nix options for:
- Quality profiles (definitions with quality groups, custom formats)
- Media management (root folders, file naming, import/export settings)
- Indexers (from Prowlarr sync or manual)
- Download clients (qBittorrent, etc.)
- Import lists (Plex, Trakt, etc.)
- Application settings (general, UI, security)

6. **Radarr Configuration Module**

- Location: `features/media/radarr/config.nix` (new file)
- Define Nix options for:
- Quality profiles (definitions with quality groups, custom formats)
- Media management (root folders, file naming, import/export settings)
- Indexers (from Prowlarr sync or manual)
- Download clients (qBittorrent, etc.)
- Import lists (Plex, Trakt, etc.)
- Application settings (general, UI, security)

7. **Lidarr Configuration Module**

- Location: `features/media/lidarr/config.nix` (new file)
- Define Nix options for:
- Quality profiles (definitions with quality groups, custom formats)
- Media management (root folders, file naming, import/export settings)
- Indexers (from Prowlarr sync or manual)
- Download clients (qBittorrent, etc.)
- Import lists (Last.fm, Spotify, etc.)
- Application settings (general, UI, security)

8. **Readarr Configuration Module**

- Location: `features/media/readarr/config.nix` (new file)
- Define Nix options for:
- Quality profiles (definitions with quality groups, custom formats)
- Media management (root folders, file naming, import/export settings)
- Indexers (from Prowlarr sync or manual)
- Download clients (qBittorrent, etc.)
- Import lists (Goodreads, etc.)
- Application settings (general, UI, security)

9. **Jellyseerr Configuration Module**

- Location: `features/media/jellyseerr/config.nix` (new file)
- Define Nix options for:
- Sonarr/Radarr integration (API keys, URLs)
- Application settings (general, notifications, UI)
- User management (if supported by Buildarr)

### Phase 3: Service Module Updates (2-3 days)

10. **Update Each *Arr Service Module**

- For each service (prowlarr, sonarr, radarr, lidarr, readarr):
- Update `features/media/{service}/default.nix`
- Add import for config module
- Add configuration options
- Keep existing systemd service setup (no changes needed)
- Add Buildarr dependency (service should start after Buildarr applies config)

11. **Update Jellyseerr Module**

- Update `features/media/jellyseerr/default.nix`
- Add Buildarr configuration integration
- Keep NixOS native service (already using `services.jellyseerr`)

### Phase 4: Integration & Testing (3-4 days)

12. **Create Unified Buildarr Configuration Generator**

- Location: `features/media/buildarr/generate-config.nix` (new file)
- Combine all service configurations into single Buildarr YAML
- Handle service dependencies (Prowlarr must be configured before others)
- Generate complete `buildarr.yml` file

13. **Update Mimir Host Configuration**

- Location: `hosts/mimir/flake.nix`
- Enable Buildarr feature module
- Enable all *Arr services with declarative config
- Configure each service's settings in Nix
- Add service dependencies (Buildarr → Prowlarr → Sonarr/Radarr/etc.)

14. **Create Initial Secrets**

- Create encrypted secret files for all *Arr service API keys
- Add secrets to `secrets/secrets.nix`
- Configure agenix secret references in Buildarr module
- Test secret decryption on mimir host

15. **Test Configuration Application**

- Test Buildarr applying configurations to each service
- Verify idempotency (running multiple times produces no changes)
- Test configuration updates (modify Nix, rebuild, verify changes applied)
- Test service dependencies (Prowlarr sync to Sonarr/Radarr)

### Phase 5: Documentation & Polish (1-2 days)

16. **Documentation**

- Document configuration options for each service
- Create examples for common scenarios
- Document migration process
- Update README with new declarative approach

17. **Handle Unsupported Services**

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

**Buildarr Infrastructure:**
- `features/media/buildarr/default.nix` - Buildarr service module
- `features/media/buildarr/config.nix` - Unified Buildarr configuration
- `features/media/buildarr/generate-config.nix` - YAML generator with secret integration
- `features/media/buildarr/secrets.nix` - Secret references for Buildarr module

**Service Configuration Modules:**
- `features/media/prowlarr/config.nix` - Prowlarr declarative configuration
- `features/media/sonarr/config.nix` - Sonarr declarative configuration
- `features/media/radarr/config.nix` - Radarr declarative configuration
- `features/media/lidarr/config.nix` - Lidarr declarative configuration
- `features/media/readarr/config.nix` - Readarr declarative configuration
- `features/media/jellyseerr/config.nix` - Jellyseerr declarative configuration

**Secret Management:**
- `secrets/.gitignore` - Ignore unencrypted secret files
- `secrets/secrets.nix` - Agenix secrets definition (lists all secrets per host)
- `secrets/services/buildarr/*.age` - Buildarr API keys (encrypted files)
- `secrets/services/prowlarr/*.age` - Prowlarr secrets (encrypted files)
- `secrets/services/sonarr/*.age` - Sonarr secrets (encrypted files)
- `secrets/services/radarr/*.age` - Radarr secrets (encrypted files)
- `secrets/services/lidarr/*.age` - Lidarr secrets (encrypted files)
- `secrets/services/readarr/*.age` - Readarr secrets (encrypted files)

### Modified Files

**Service Modules:**
- `features/media/prowlarr/default.nix` - Add configuration options and secret integration
- `features/media/sonarr/default.nix` - Add configuration options and secret integration
- `features/media/radarr/default.nix` - Add configuration options and secret integration
- `features/media/lidarr/default.nix` - Add configuration options and secret integration
- `features/media/readarr/default.nix` - Add configuration options and secret integration
- `features/media/jellyseerr/default.nix` - Add configuration options and secret integration

**Host Configuration:**
- `hosts/mimir/flake.nix` - Enable all services with declarative config, add agenix input and module

## Success Criteria

- All supported *Arr settings managed in Nix configuration
- Configuration changes applied automatically via Buildarr
- No manual web UI configuration required for supported services
- Configuration is version-controlled and reproducible
- Service dependencies properly handled (Prowlarr → others)
- Idempotent configuration application
- Ready to extend to additional *Arr applications

## Risks & Considerations

- **API Key Management:** Using agenix with SSH host keys for secure secret storage
- **Secret Management:** Need to maintain `secrets.nix` and encrypted secret files
- **Buildarr Maintenance:** External dependency that needs updates
- **Configuration Drift:** Need to ensure Buildarr keeps config in sync
- **Service Dependencies:** Must ensure proper startup order (Buildarr → Prowlarr → others)
- **Unsupported Services:** Whisparr and Overseerr remain manual
- **Secret Rotation:** No rotation strategy defined yet (deferred per requirements)
- **Host Key Management:** SSH host keys must be securely stored and backed up

## Timeline Estimate

- Phase 1: 2-3 days
- Phase 2: 3-4 days
- Phase 3: 2-3 days
- Phase 4: 3-4 days
- Phase 5: 1-2 days
**Total: 11-16 days**

### To-dos

**Phase 1: Buildarr Infrastructure Setup**
- [ ] Create Buildarr feature module with systemd service (features/media/buildarr/default.nix)
- [ ] Design unified Buildarr configuration structure (features/media/buildarr/config.nix)
- [ ] Set up agenix infrastructure (secrets/secrets.nix, directory structure)
- [ ] Add agenix input and module to hosts/mimir/flake.nix
- [ ] Create Buildarr system user with appropriate permissions

**Phase 2: Service-Specific Configuration Modules**
- [ ] Create Prowlarr configuration module with Nix options (features/media/prowlarr/config.nix)
- [ ] Create Sonarr configuration module with Nix options (features/media/sonarr/config.nix)
- [ ] Create Radarr configuration module with Nix options (features/media/radarr/config.nix)
- [ ] Create Lidarr configuration module with Nix options (features/media/lidarr/config.nix)
- [ ] Create Readarr configuration module with Nix options (features/media/readarr/config.nix)
- [ ] Create Jellyseerr configuration module with Nix options (features/media/jellyseerr/config.nix)

**Phase 3: Service Module Updates**
- [ ] Update all *Arr service modules to integrate configuration options and secrets
- [ ] Update Jellyseerr module with Buildarr configuration integration

**Phase 4: Integration & Testing**
- [ ] Create unified Buildarr YAML generator with secret integration (features/media/buildarr/generate-config.nix)
- [ ] Update mimir host configuration to enable all services with declarative config
- [ ] Create initial encrypted secrets for all *Arr service API keys
- [ ] Test secret decryption and file permissions on mimir host
- [ ] Test configuration application, idempotency, and service dependencies

**Phase 5: Documentation & Polish**
- [ ] Document configuration options for each service
- [ ] Document secret management workflow (creating, updating, encrypting secrets)
- [ ] Create examples for common scenarios
- [ ] Update README with new declarative approach and secrets management
- [ ] Document unsupported services (Whisparr, Overseerr) limitations