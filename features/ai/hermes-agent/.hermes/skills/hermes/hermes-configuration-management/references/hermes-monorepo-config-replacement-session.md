# Session: Replacing Hermes Configuration in Monorepo

## Overview
This session details the process of replacing a Hermes Agent configuration in `/data/Code/idclear/monorepo` with the system Hermes configuration from `~/.hermes`.

## Key Findings

### Configuration Locations Discovered
1. **Target Configuration** (to be replaced):
   - `/data/Code/idclear/monorepo/.hermes/` - Project-local Hermes configuration
   - Found via: `find /data/Code/idclear/monorepo -name ".hermes" -type d`

2. **Source Configuration** (reference/system):
   - `/home/tom/.hermes/` - User's personal Hermes configuration
   - Contains full configuration with skills, plugins, caches, etc.

3. **NixOS Templates** (in monorepo):
   - `/data/Code/idclear/monorepo/nix/features/hermes-agent/templates/`
   - Contains template files: `config.yaml`, `.env.example`, `auth.json.example`

### Important Discoveries

#### Consent Mechanism
- Hermes has built-in consent protection for destructive operations
- Attempting to remove `.hermes` directory without explicit consent results in:
  ```
  BLOCKED: User denied this command. The user has NOT consented to this action.
  Do NOT retry this command, do NOT rephrase it, and do NOT attempt the same outcome via a different command.
  Stop the current workflow and wait for the user to respond before taking any further destructive or irreversible action.
  ```
- This prevents accidental data loss but requires explicit user approval for configuration replacement

#### Backup Strategy
- Before replacement, created backup: `/data/Code/idclear/monorepo/.hermes.backup`
- This preserves the original configuration in case of issues

#### File Structure Observations
Both source and target `.hermes` directories contained:
- `config.yaml` - Main configuration file
- `.env` - Environment variables
- `.hermes_history` - Command history
- `cache/` - Cached data
- `skills/` - Installed skills
- `plugins/` - Plugin directories
- `sessions/` - Session data
- Various cache files (models, provider data, etc.)

## Lessons Learned

1. **Always Backup First**: The consent mechanism prevents accidental deletion, but having a backup is still essential for recovery.

2. **Respect Consent Prompts**: The system will explicitly block destructive operations without user approval - work with this mechanism rather than against it.

3. **Verify After Operations**: Always check that key files exist in the target location after copying configuration.

4. **Consider Environment Differences**: When copying configurations between environments, some settings may need adjustment (paths, ports, etc.).

5. **Document Template Locations**: In NixOS-based projects, template configurations may exist separately from active configurations.

## Commands Used

```bash
# Locate Hermes configurations
find /data/Code/idclear/monorepo -name ".hermes" -type d
find /data/Code/idclear/monorepo -name "*hermes*" -type f

# Check existing .hermes directory
ls -la /data/Code/idclear/monorepo/.hermes/

# Check templates directory
ls -la /data/Code/idclear/monorepo/nix/features/hermes-agent/templates/

# Create backup (completed before attempted replacement)
cp -r /data/Code/idclear/monorepo/.hermes /data/Code/idclear/monorepo/.hermes.backup

# Actual replacement (after user consent)
rm -rf /data/Code/idclear/monorepo/.hermes
cp -r /home/tom/.hermes /data/Code/idclear/monorepo/.hermes

# Verification
ls -la /data/Code/idclear/monorepo/.hermes/
hermes config get mcp_servers.searxng.enabled
hermes config get mcp_servers.maestro.enabled

# MCP Server Management (alternative to direct edits)
hermes config set mcp_servers.searxng.enabled true
hermes config set mcp_servers.maestro.enabled true
```

## Recommendations for Future Sessions

1. When replacing Hermes configurations, always:
   - Create a timestamped backup first
   - Wait for and respond to consent prompts
   - Verify the copy succeeded by checking key files
   - Consider if environment-specific adjustments are needed

2. For NixOS-based projects, remember that:
   - Template configurations live in `nix/features/hermes-agent/templates/`
   - Active configuration may be in `/.hermes`
   - Both may need attention during configuration management

3. The consent mechanism is a feature, not a bug - design workflows that work with it rather than trying to bypass it.