# Summary of Multi-Host NixOS Control Plan (2026-08-19)

This document summarizes the plan for managing multiple NixOS hosts (Drakkar, Huginn, Mimir) from any device, including enabling AI agent command issuance.

## Key Components

1. **SSH Key Infrastructure for Hermes Agent**
   - Dedicated Ed25519 key pair: `~/.hermes/keys/nixos_mgmt`
   - Deployed to all hosts via ssh-copy-id
   - SSH config in `~/.hermes/ssh/config` with proper settings

2. **Fleet Management Tools**
   - **Primary**: Colmena (github:nix-community/colmena) for fleet operations, parallel deployment, health checks
   - **Secondary**: deploy-rs (github:serokell/deploy-rs) for multi-profile safety features

3. **Unified Management Script**: `nixos-mgmt`
   - Provides consistent interface for: status, deploy, update, exec, rollback, health, fleet operations
   - Wraps SSH and fleet tool commands with proper error handling and logging
   - Located at `~/.hermes/bin/nixos-mgmt`

4. **Usage Patterns**
   - Manual: `nixos-mgmt status drakkar`, `nixos-mgmt fleet exec -- "uptime"`
   - AI Agent: Same interface, enabling cross-host command issuance
   - Advanced: Tag-based targeting, health-check-gated deployments

5. **Security Hardening**
   - SSH key restrictions, IdentitiesOnly, ServerAlive settings
   - Optional sudoers for specific nixos-rebuild operations if needed
   - Audit logging and regular key rotation

6. **Maintenance**
   - Daily: Basic status checks
   - Weekly: Health checks, flake updates
   - Monthly: Key rotation, access log review, procedure testing

## Benefits
- Unified control from any device with SSH access
- AI agent capable of safe cross-host operations
- Built-in safety via health checks and rollbacks
- Stateless design reduces attack surface
- Integrates with existing NixOS workflows

See the full plan in bitar for detailed rationale, implementation steps, and risk mitigation strategies.