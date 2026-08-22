---
name: hermes-configuration-management
description: Manages backing up, replacing, synchronizing, and restoring Hermes Agent configurations across different installations or environments.
category: hermes
---

# Hermes Configuration Management

Manages backing up, replacing, synchronizing, and restoring Hermes Agent configurations across different installations or environments.

## When to Use

- Synchronizing Hermes configuration between development and production environments
- Replacing a local Hermes configuration with a reference/system configuration
- Backing up Hermes configuration before making experimental changes
- Restoring Hermes configuration from a known-good backup
- Setting up Hermes in a new environment based on an existing configuration
- Discovering which providers Hermes supports and which offer free model tiers

## Step-by-Step Procedure

### 1. Locate Hermes Configurations
Identify both the source (reference) and target (to be replaced) Hermes configurations:
```bash
# Find existing Hermes configurations in a monorepo or project
find /path/to/project -name ".hermes" -type d
find /path/to/project -name "*hermes*" -type f

# Common locations to check:
# - ~/.hermes (user's personal configuration)
# - /path/to/project/.hermes (project-local configuration)
# - /path/to/project/nix/features/hermes-agent/ (NixOS configuration templates)
```

### 2. Create Backup of Target Configuration
Always backup before making changes:
```bash
# Create timestamped backup
cp -r /path/to/target/.hermes /path/to/target/.hermes.backup_$(date +%Y%m%d_%H%M%S)

# Or simple backup
cp -r /path/to/target/.hermes /path/to/target/.hermes.backup
```

### 3. Copy Source Configuration to Target
Replace target configuration with source:
```bash
# Remove existing target (if any) and copy source
rm -rf /path/to/target/.hermes
cp -r /path/to/source/.hermes /path/to/target/.hermes

# Preserve attributes if needed
# cp -r --preserve=all /path/to/source/.hermes /path/to/target/.hermes
```

### 4. Verify the Copy
Check that the configuration was copied correctly:
```bash
# Verify key files exist
ls -la /path/to/target/.hermes/
ls -la /path/to/target/.hermes/config.yaml
ls -la /path/to/target/.hermes/.env

# Compare with source (optional)
diff -r /path/to/source/.hermes /path/to/target/.hermes
```

### 5. Handle Consent Requirements
Be aware that some Hermes operations require explicit user consent:
- Destructive actions like removing configurations may be blocked
- The system will prompt for confirmation before proceeding
- Do not attempt to bypass consent mechanisms
- Wait for and respond to consent prompts appropriately

## Common Pitfalls to Avoid

### Forgetting to Backup
**Problem:** Making changes without creating a backup first, risking loss of working configuration.
**Solution:** Always create a backup before copying or removing any Hermes configuration directory.
**Verification:** Confirm backup exists and contains expected files before proceeding.

### Overlooking File Attributes
**Problem:** Copying configuration without preserving permissions, timestamps, or symbolic links.
**Solution:** Use `cp -r --preserve=all` when file attributes are important, or verify that default copy behavior preserves what's needed for your use case.
**Verification:** Check critical file permissions and links after copying.

### Assuming Consent is Granted
**Problem:** Attempting destructive actions without waiting for explicit user consent, leading to blocked operations.
**Solution:** Always wait for and respect the system's consent prompts for destructive operations like removing configurations.
**Verification:** Check command output for consent requests and respond appropriately.

### Copying to Wrong Location
**Problem:** Copying configuration to an incorrect directory path.
**Solution:** Double-check target paths before executing copy commands, especially when working with multiple similar paths.
**Verification:** Use `pwd` to confirm current directory and verify absolute paths before copying.

### Neglecting to Verify Success
**Problem:** Assuming the copy succeeded without checking, leading to undetectable configuration issues.
**Solution:** Always verify that key configuration files exist in the target location after copying AND validate their content/syntax.
**Verification:** 
- Check for `config.yaml`, `.env`, and directory structure in the target `.hermes` folder.
- Validate syntax of modified configuration files (e.g., yamllint for YAML, jq for JSON, nix-instantiate --parse for Nix)
- For application configuration, run associated tests to ensure functionality is preserved

### Attempting Direct File Edits
**Problem:** Trying to edit Hermes configuration files directly when the system blocks such modifications for security reasons.
**Solution:** Use `hermes config set/get` commands for modifying configuration values instead of direct file edits.
**Verification:** Check if the system prompts you to use `hermes config` when attempting direct edits.
**Example from session:** When attempting to patch `/home/tom/.hermes/config.yaml` directly to enable MCP servers, the system refused with: "Refusing to write to Hermes config file: /home/tom/.hermes/config.yaml — Agent cannot modify security-sensitive configuration. Edit ~/.hermes/config.yaml directly or use 'hermes config' instead." The correct approach was to use `hermes config set mcp_servers.<server-name>.enabled true` for each server.

### Making Unrequested Changes
**Problem:** Making configuration or code changes when the user only requested analysis, reporting, or information gathering.
**Solution:** Always clarify user intent before making modifications. When asked to "analyze and report" or similar phrases, limit actions to investigation and reporting only unless explicitly authorized to make changes.
**Verification:** Before running any modification commands (like `hermes config set`, `patch`, `write_file`), confirm with the user that changes are expected and desired.

## Using hermes config for Individual Settings

For modifying specific configuration values without replacing entire files, use the `hermes config` command:

```bash
# Set a configuration value
hermes config set <key> <value>

# Get a configuration value
hermes config get <key>

# List all configuration
hermes config list
```

**Note**: Direct edits to configuration files in `~/.hermes` or project `.hermes` directories may be blocked for security reasons. The system will prompt to use `hermes config` instead when attempting to modify sensitive settings.

**Example - Enabling MCP Servers**:
```bash
# Enable the roam-code MCP server
hermes config set mcp_servers.roam-code.enabled true

# Enable the context7 MCP server
hermes config set mcp_servers.context7.enabled true

# Enable the serena MCP server
hermes config set mcp_servers.serena.enabled true

# Verify the changes
hermes config get mcp_servers.roam-code.enabled
hermes config get mcp_servers.context7.enabled
hermes config get mcp_servers.serena.enabled
```

## Validation

After replacing configuration, validate that Hermes functions correctly:

```bash
# Test basic Hermes operation
hermes --version

# Test configuration loading
hermes config get model.default

# If using in a development environment with devenv:
devenv shell
hermes --version
```

## Notes

- Hermes configuration includes both user-specific settings (API keys, preferences) and system settings (model configurations, tool configurations)
- Be cautious when sharing configurations that may contain sensitive information like API keys
- Consider using `.env.example` templates and actual `.env` files with proper secret management
- Some configuration elements may be environment-specific (paths, ports, etc.) and require adjustment after copying
- **Critical**: Always respect Hermes' consent mechanism for destructive operations - the system will block actions like removing configurations without explicit user approval
- **Best Practice**: Use `hermes config set` for individual MCP server enables/disables rather than editing config files directly
- **Verification**: After enabling/disabling MCP servers, verify with `hermes config get mcp_servers.<server_name>.enabled`
- **Communication**: When user requests analysis/reporting, focus on investigation and communication rather than making unsolicited changes
- **Analysis-Only Requests**: When user asks to analyze or report (e.g., "analyze why", "explain", "report"), limit actions to investigation and reporting only; do not make configuration or code changes unless explicitly authorized.
- **Build-Time Variables**: Some variables like `NEXT_PUBLIC_*` are inlined at build time (e.g., in Dockerfiles); changing `.env` at runtime will not affect them; you may need to rebuild images with correct build-args.

## Handling Consent Requirements

Be aware that some Hermes operations require explicit user consent:
- Destructive actions like removing configurations may be blocked
- The system will prompt for confirmation before proceeding
- Do not attempt to bypass consent mechanisms
- Wait for and respond to consent prompts appropriately

When you encounter a consent requirement:
1. Read the prompt carefully to understand what action is being requested
2. Respond with "yes" to proceed or provide alternative instructions
3. The operation will not proceed without explicit consent
4. Common operations requiring consent:
   - Removing Hermes configuration directories (`rm -rf .hermes`)
   - Certain destructive configuration changes
   - Some MCP server modifications via direct file edits

## Reference Configuration Locations

### System/User Configuration
- `~/.hermes` - Personal Hermes configuration
- Contains: `config.yaml`, `.env`, skills, plugins, caches, logs

### Project/Local Configuration
- `./.hermes` - Project-specific Hermes configuration
- Often found in monorepos or development environments

### NixOS Templates
- `./nix/features/hermes-agent/templates/` - Template configurations for NixOS deployments
- Contains: `config.yaml`, `.env.example`, `auth.json.example`

## Related Skills

- `hermes-plugin-development` - For developing Hermes plugins that may interact with configuration
- `hermes-lmstudio-connection` - For configuring specific model connections
- `hermes-provider-and-free-model-discovery` - For enumerating supported providers and free model tiers
- `skill-library-structure` - For understanding how Hermes skills are organized
