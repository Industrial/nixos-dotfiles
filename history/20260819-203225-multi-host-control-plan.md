# Multi-Host NixOS Control Plan
**Date**: 2026-08-19  
**Hosts**: Drakkar (current), Huginn (Tablet), Mimir (File Server)  
**Objective**: Enable easy control of any device from any other device, including AI agent command issuance

## Executive Summary

This plan outlines a secure, robust system for managing multiple NixOS hosts (Drakkar, Huginn, Mimir) from any device, with special focus enabling the Hermes AI agent to issue commands across the fleet. The solution combines Colmena for fleet management and deploy-rs for multi-profile safety features, accessed through a unified wrapper script.

## Current Setup Analysis

### Existing Infrastructure
- **Individual host flakes**: `hosts/huginn/flake.nix`, `hosts/mimir/flake.nix`, `hosts/drakkar/flake.nix`
- **Standardized feature lists**: Recently updated to ensure consistency across hosts
- **Update scripts**: 
  - `bin/update/system`: Runs `nixos-rebuild switch --flake ".#$(hostname)"`
  - `bin/update/host`: Wrapper that calls system update
- **No existing multi-host tools**: No references to colmena, deploy-rs, or similar fleet managers

### Limitations of Current Approach
- Manual host-by-host updates required
- No built-in health checks or rollback mechanisms
- Difficult to execute coordinated commands across multiple hosts
- AI agent lacks secure, standardized interface for cross-host operations

## Recommended Solution: Hybrid Colmena + deploy-rs Approach

### Primary Tool: **Colmena**
- **Purpose**: Fleet management, parallel deployment, stateless orchestration
- **Selection Criteria**:
  - Declarative configuration from single flake source
  - Parallel SSH deployments for efficiency
  - Built-in health checks and atomic rollbacks
  - Tag-based node selection (ideal for grouping hosts by function)
  - `colmena exec` command for arbitrary host execution
  - Stateless design (no persistent daemon to secure)
  - Active community and Rust-based for reliability

### Secondary Tool: **deploy-rs**
- **Purpose**: Multi-profile deployments with enhanced safety
- **Selection Criteria**:
  - Multi-profile deployment (base OS + services separately)
  - Sophisticated rollback handling with health checks
  - Support for lesser-privileged deployments
  - Complements colmena's fleet-level operations with service-level granularity
  - Also Rust-based and well-maintained

### Why Not Alternatives?
- **nixos-rebuild --target-host**: Good for single hosts but lacks fleet features, health checks, easy parallelism
- **NixOps**: More complex, stateful, overkill for 3-host setup
- **morph/nixinate**: Lesser adoption compared to colmena/deploy-rs
- **nixos-anywhere**: Great for initial install but not ongoing management

## Implementation Plan

### Phase 1: Foundation & Access (Days 1-2)

#### 1.1 SSH Key Infrastructure for Hermes Agent
```bash
# Create dedicated key pair for AI agent
mkdir -p ~/.hermes/keys
ssh-keygen -t ed25519 -f ~/.hermes/keys/nixos_mgmt -N "" -C "hermes-agent@nixos-fleet"

# Deploy to all hosts
for host in drakkar huginn mimir; do
  ssh-copy-id -i ~/.hermes/keys/nixos_mgmt.pub tom@$host
done

# Verify access
for host in drakkar huginn mimir; do
  echo "Testing $host:"
  ssh -i ~/.hermes/keys/nixos_mgmt tom@$host "hostname && echo 'SSH OK'"
done
```

#### 1.2 SSH Configuration for Hermes
Create `~/.hermes/ssh/config`:
```
Host drakkar huginn mimir
  User tom
  HostName %h
  IdentityFile ~/.hermes/keys/nixos_mgmt
  IdentitiesOnly yes
  ServerAliveInterval 60
  ServerAliveCountMax 3
  StrictHostKeyChecking accept-new
  LogLevel INFO
```

#### 1.3 Test Basic Connectivity
```bash
# Test from any machine with the key
ssh -F ~/.hermes/ssh/config drakkar "hostname"
ssh -F ~/.hermes/ssh/config huginn "hostname"  
ssh -F ~/.hermes/ssh/config mimir "hostname"
```

### Phase 2: Tool Integration (Days 3-5)

#### 2.1 Update Flake Structure (Recommended Improvement)
Transform from individual host flakes to unified structure:

**Option A: Unified Flake (Recommended)**
Create `/home/tom/.dotfiles/flake.nix`:
```nix
{
  description = "Multi-host NixOS configuration for Drakkar, Huginn, Mimir";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # ... existing inputs (hyprland, quickshell, etc.)
    colmena = {
      url = "github:nix-community/colmena";
      flake = false;
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
    };
  };

  outputs = { self, nixpkgs, colmena, deploy-rs, ... }: {
    nixosConfigurations = {
      drakkar = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/drakkar/configuration.nix ./hosts/drakkar/hardware.nix ... ];
      };
      huginn = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux"; 
        modules = [ ./hosts/huginn/configuration.nix ./hosts/huginn/hardware.nix ... ];
      };
      mimir = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/mimir/configuration.nix ./hosts/mimir/hardware.nix ... ];
      };
    };

    # Colmana configuration
    colmena = colmena.lib.colmena {
      # ... colmena config
    };

    # deploy-rs configuration  
    deploy-rs = deploy-rs.lib.deploy-rs {
      # ... deploy-rs config
    };
  };
}
```

**Option B: Incremental Approach (Keep existing flakes, add tools as overlays)**
Add to each host's flake.nix:
```nix
inputs = {
  # ... existing
  colmena = {
    url = "github:nix-community/colmena";
    flake = false;
  };
  deploy-rs = {
    url = "github:serokell/deploy-rs";
  };
};

# Then in outputs or wherever needed
```

#### 2.2 Install and Test Tools
```bash
# Test colmena availability
nix run github:nix-community/colmena -- --help

# Test deploy-rs availability  
nix run github:serokell/deploy-rs -- --help

# Test basic colmena functionality (from repo root)
colmena check drakkar
colmena check huginn  
colmena check mimir
```

### Phase 3: AI Command Interface (Days 6-7)

#### 3.1 Create Unified Management Script
`~/.hermes/bin/nixos-mgmt`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# ==== Configuration ====
KEY_FILE="$HOME/.hermes/keys/nixos_mgmt"
DOTFILES_ROOT="$HOME/.dotfiles" 
SSH_CONFIG="$HOME/.hermes/ssh/config"
COLMENA_CMD="nix run github:nix-community/colmena --"
DEPLOY_RS_CMD="nix run github:serokell/deploy-rs --"
# =======================

usage() {
  cat << EOF
Usage: $0 <command> [args]

Commands:
  status <host>          - Check host NixOS version and connectivity
  deploy <host>          - Deploy configuration to host (colmena)
  update <host>          - Update flake and deploy to host
  exec <host> <command>  - Execute arbitrary command on host via SSH
  rollback <host>        - Rollback last deployment on host
  health <host>          - Run health checks on host
  fleet <command>        - Run command across all hosts (colmena)
  help                   - Show this help

Examples:
  $0 status drakkar
  $0 exec huginn "df -h"
  $0 fleet exec -- "uptime"
  $0 deploy mimir
EOF
  exit 1
}

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error() { log "ERROR: $*" >&2; }

# ==== Command Implementations ====

cmd_status() {
  local host="$1"; shift
  log "Checking status of $host"
  ssh -F "$SSH_CONFIG" "tom@$host" "sudo nixos-version || echo 'Failed to get version'"
}

cmd_deploy() {
  local host="$1"; shift
  log "Deploying configuration to $host via colmena"
  cd "$DOTFILES_ROOT"
  $COLMENA_CMD deploy --target "$host" --verbose "$@"
}

cmd_update() {
  local host="$1"; shift
  log "Updating flake and deploying to $host"
  cd "$DOTFILES_ROOT"
  git pull --rebase || log "Warning: Git pull had issues"
  $COLMENA_CMD update --target "$host" --verbose "$@"
}

cmd_exec() {
  local host="$1"; shift
  local command="$*"
  [[ -z "$command" ]] && { error "No command specified"; return 1; }
  log "Executing on $host: $command"
  ssh -F "$SSH_CONFIG" "tom@$host" "$command"
}

cmd_rollback() {
  local host="$1"; shift
  log "Rolling back last deployment on $host"
  cd "$DOTFILES_ROOT"
  $COLMENA_CMD rollback --target "$host"
}

cmd_health() {
  local host="$1"; shift
  log "Running health checks on $host"
  cd "$DOTFILES_ROOT"
  $COLMENA_CMD check --target "$host"
}

cmd_fleet() {
  local subcmd="$1"; shift
  [[ -z "$subcmd" ]] && { error "No fleet subcommand specified"; return 1; }
  log "Running fleet command: $subcmd $*"
  cd "$DOTFILES_ROOT"
  $COLMENA_CMD "$subcmd" "$@"
}

# ==== Main Dispatch ====

main() {
  [[ $# -lt 1 ]] && usage
  
  local cmd="$1"; shift
  
  case "$cmd" in
    status)   cmd_status "$@" ;;
    deploy)   cmd_deploy "$@" ;;
    update)   cmd_update "$@" ;;
    exec)     cmd_exec "$@" ;;
    rollback) cmd_rollback "$@" ;;
    health)   cmd_health "$@" ;;
    fleet)    cmd_fleet "$@" ;;
    help)     usage ;;
    *)        error "Unknown command: $cmd"; usage ;;
  esac
}

main "$@"
```

Make executable: `chmod +x ~/.hermes/bin/nixos-mgmt`

#### 3.2 Add to Hermes PATH
Ensure `~/.hermes/bin` is in PATH for Hermes agent sessions.

#### 3.3 Test AI Interface
```bash
# Test all commands
nixos-mgmt status drakkar
nixos-mgmt exec huginn "whoami"
nixos-mgmt health mimir
nixos-mgmt fleet exec -- "hostname"
```

### Phase 4: Security Hardening (Ongoing)

#### 4.1 SSH Security
- Use Ed25519 keys (already implemented)
- Key agent with timeout for interactive use
- Consider certificate-based auth for larger fleets
- Regular key rotation (every 90 days)

#### 4.2 Sudo Precautions (If Needed)
For operations requiring sudo on targets (like `nixos-rebuild` via SSH):
```bash
# Create /etc/sudoers.d/hermes-agent on each host:
tom ALL=(root) NOPASSWD: /run/current-system/bin/switch-to-configuration
tom ALL=(root) NOPASSWD: /nix/var/nix/profiles/*/bin/switch-to-configuration
```
**Note**: Colmena typically handles this internally when using `--target-host` with proper SSH setup.

#### 4.3 Network Security
- Restrict SSH access to trusted networks/IPs if possible
- Consider using WireGuard or Tailscale for encrypted mesh network
- Monitor `/var/log/auth.log` on hosts for suspicious access

#### 4.4 Audit Logging
Enable verbose logging for all operations:
- Colmena/deploy-rs already provide good output
- Consider adding auditd rules for critical file access
- Log all Hermes agent commands to persistent storage

## Usage Patterns

### Manual Control (From Any Device)
```bash
# 1. Ensure you have SSH access and Hermes keys
# 2. Navigate to dotfiles or use the mgmt script

# Check all hosts
nixos-mgmt status drakkar
nixos-mgmt status huginn  
nixos-mgmt status mimir

# Execute diagnostic command everywhere
nixos-mgmt fleet exec -- "df -h | grep -vE '^Filesystem|tmpfs'"

# Update specific host
nixos-mgmt update huginn

# Deploy to all hosts (parallel)
nixos-mgmt fleet deploy

# Check health of file server
nixos-mgmt health mimir

# Rollback problematic update
nixos-mgmt rollback drakkar
```

### AI Agent Operations
The Hermes AI can now issue commands like:
```bash
# Check system status across fleet
nixos-mgmt fleet exec -- "uptime"

# Deploy security updates
nixos-mgmt fleet deploy

# Gather logs from all hosts
nixos-mgmt fleet exec -- "journalctl --since '1 hour ago' | grep -i error"

# Check disk usage on tablet (huginn)
nixos-mgmt exec huginn "lsblk && df -h"

# Restart specific service on file server
nixos-mgmt exec mimir "sudo systemctl restart smbd"

# Validate configuration across fleet
nixos-mgmt fleet exec -- "sudo nixos-rebuild test --dry-run"
```

### Advanced Fleet Operations
```bash
# Deploy to specific group (if you define tags in colmena.nix)
# Example: tag mimir as "storage", huginn as "mobile"
nixos-mgmt fleet deploy --targets "storage"

# Execute on multiple specific hosts
nixos-mgmt fleet exec --targets "drakkar,huginn" -- "docker system prune -f"

# Health check all before deploying
nixos-mgmt fleet check && nixos-mgmt fleet deploy
```

## Benefits and Advantages

### For Manual Users
1. **Unified Interface**: Single command to control all hosts
2. **Efficiency**: Parallel operations save time
3. **Safety**: Health checks prevent bad deployments
4. **Flexibility**: Works from any machine with SSH keys
5. **Visibility**: Clear output and logging

### For AI Agent (Hermes)
1. **Standardized API**: Consistent interface via `nixos-mgmt`
2. **Discoverability**: Built-in help and command structure
3. **Safety**: Inherits tool safety features (health checks, rollbacks)
4. **Auditability**: All commands logged and traceable
5. **Extensibility**: Easy to add new commands or tools

### Technical Advantages
1. **Stateless Design**: No persistent services to compromise
2. **SSH-Based**: Leverages existing secure channel
3. **Declarative**: Configuration as code in Git
4. **Atomic Operations**: Where supported by underlying tools
5. **Rollback Capability**: Critical for maintaining stability

## Next Steps and Recommendations

### Immediate Actions (Week 1)
1. [ ] Implement SSH key pair for Hermes agent
2. [ ] Deploy keys to all three hosts
3. [ ] Create and test `nixos-mgmt` wrapper script
4. [ ] Test basic colmena/deploy-rs availability
5. [ ] Document procedures in team wiki

### Short-Term Improvements (Weeks 2-3)
1. [ ] Evaluate migrating to unified flake structure
2. [ ] Define host tags in colmena (e.g., "storage", "mobile", "primary")
3. [ ] Implement health check definitions in colmena
4. [ ] Add secret management (sops-nix or age) for sensitive data
5. [ ] Create runbook for common operations

### Long-Term Enhancements (Month 2+)
1. [ ] Consider adding monitoring (Prometheus + Grafana) via fleet
2. [ ] Implement automated health-based deployment triggers
3. [ ] Explore integration with NixOS machine credentials for secrets
4. [ ] Add configuration drift detection and alerting
5. [ ] Evaluate fleet-wide backup strategies

## Risk Mitigation

### Rollback Procedures
- **Failed deployment**: Colmena/deploy-rs automatically rollback on health check failure
- **Manual rollback**: `nixos-mgmt rollback <host>`
- **Emergency access**: Direct console access always available as fallback

### Failure Scenarios
1. **SSH key compromised**: 
   - Revoke key from `~/.hermes/keys/nixos_mgmt.pub` on all hosts
   - Generate new key pair and redistribute
2. **Network partition**: 
   - Operations fail safely; hosts maintain last known good state
   - Local console access unaffected
3. **Tool malfunction**: 
   - Fall back to direct `nixos-rebuild --target-host` 
   - Manual intervention always possible
4. **Configuration error**: 
   - Health checks prevent propagation
   - Individual host recovery via local console

## Maintenance Schedule

### Daily
- Check fleet status: `nixos-mgmt fleet exec -- "uptime"`
- Review logs for anomalies

### Weekly  
- Run health checks: `nixos-mgmt fleet check`
- Update flake inputs: `nix flake update`
- Verify SSH access to all hosts

### Monthly
- Rotate SSH keys for Hermes agent
- Review access logs and sudo usage
- Test rollback procedures on non-critical host
- Update colmena/deploy-rs to latest versions

## Conclusion

This plan provides a secure, scalable foundation for managing your NixOS fleet with special consideration for AI agent operations. By combining Colmena's fleet management strengths with deploy-rs's safety features, accessed through a unified interface, you gain:

- ✅ **Easy cross-device control** from any machine with SSH keys
- ✅ **AI agent command capability** via standardized wrapper
- ✅ **Operational safety** through health checks and rollbacks  
- ✅ **Flexibility** for both individual and fleet operations
- ✅ **Maintainability** through declarative, version-controlled configuration

The implementation is incremental and reversible, allowing you to start with basic SSH access and progressively enhance functionality as needed. The Hermes agent will be able to safely issue commands across your Drakkar, Huginn, and Mimir hosts while maintaining the security and stability of your NixOS infrastructure.

---
*Prepared for: NixOS Fleet Management Initiative*  
*Repository: ~/.dotfiles*  
*Next Review: 2026-09-19*