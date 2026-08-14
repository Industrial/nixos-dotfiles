# NixOS Setup Improvements

This document lists improvements for the NixOS configuration, excluding Home Manager.

## Overview

The current NixOS setup is functional but has many areas for improvement across security, performance, reliability, and usability. These improvements are organized by category.

## Security Improvements

### 1. Full Disk Encryption (FDE)
- **Current**: Missing FDE configuration
- **Improvement**: Add `boot.initrd.luks.devices` and `boot.initrd.luks.actions` for automatic unlocking
- **Benefit**: Protects data at rest on lost/stolen devices

### 2. Secure Boot
- **Current**: Systemd-boot enabled but secureBoot commented out
- **Improvement**: Enable secureBoot with systemd-boot as bootloader
- **Benefit**: Ensures boot integrity and prevents rootkit attacks

### 3. AppArmor Profiles
- **Current**: Basic apparmor import exists but profiles not configured
- **Improvement**: Define and enable AppArmor profiles for critical services (docker, firefox, etc.)
- **Benefit**: Mandatory access control for service isolation

### 4. Kernel Hardening
- **Current**: Some kernel params in boot.nix but many commented out
- **Improvement**: Enable additional kernel hardening parameters:
  - `lockdown=confidentiality`
  - `slab_nomerge`
  - `slab_max_order=0`
  - `pti=on`
  - `vsyscall=none`
  - `debugfs=off`
  - `oops=panic`
  - `module.sig_enforce=1`
- **Benefit**: Reduced attack surface and kernel exploitation risk

### 5. SELinux or SMACK Alternatives
- **Current**: Not configured
- **Improvement**: Consider enabling SELinux as an alternative to AppArmor
- **Benefit**: Additional mandatory access control framework

## Performance Improvements

### 6. Nix Build Parallelism
- **Current**: `max-jobs = "auto"` and `cores = 0` (use all cores)
- **Improvement**: Set explicit `cores` value based on physical cores, limit `max-jobs` to avoid oversubscription
- **Benefit**: More predictable builds, better resource management

### 7. Build Timeout Configuration
- **Current**: `build-timeout = 3600` (1 hour)
- **Improvement**: Adjust based on typical build times, add warnings for long builds
- **Benefit**: Faster failure detection, prevents stuck builds

### 8. Binary Cache Optimization
- **Current**: Community caches included (nix-community.cachix, devenv.cachix)
- **Improvement**: 
  - Add more relevant binary caches
  - Configure cache priorities
  - Set up private cache for organization-specific packages
- **Benefit**: Faster builds from caches, offline capability

### 9. GC Aggressive Configuration
- **Current**: `gc-keep-derivations = true`, `gc-keep-outputs = true`, `gc.dates = "weekly"`, `gc.options = "--delete-older-than 30d"`
- **Improvement**: 
  - Add `gc.automatic = true` with more frequent runs
  - Consider `gc.options = "--delete-older-than 14d"` for faster cleanup
  - Add `extra-collectors` for custom cleanup logic
- **Benefit**: Disk space management, faster nixos-rebuild

### 10. Documentation Disabled (Good)
- **Current**: `documentation = { doc = { enable = false } ;}`
- **Benefit**: Avoids fragile doc builds, keeps system lean

### 11. Journal Log Management
- **Current**: `SystemMaxUse=1G`, `RuntimeMaxUse=256M`, `MaxFileSec=1week`
- **Improvement**: 
  - Add `SessionMaxUse` for user sessions
  - Add `FlushIntervalSec` for frequent flushing
  - Consider `RateLimitIntervalSec` and `RateLimitBurst`
- **Benefit**: Prevents log fills, faster dbus-broker reloads

## Reliability Improvements

### 12. Nix Flake Lock Management
- **Current**: Basic flake usage with `experimental-features = "nix-command flakes"`
- **Improvement**: 
  - Add locked inputs configuration
  - Add input flake verification
  - Add locked down flake registry
- **Benefit**: Reproducible builds, input integrity

### 13. Nix Store Optimisation
- **Current**: Cron job optimises nix-store weekly
- **Improvement**: 
  - Add `nix.settings.gc = true` with better options
  - Add `nix.extra-keep-derivations` and `nix.extra-keep-outputs`
  - Optimise during switch, not just cron
- **Benefit**: Smaller store, faster lookups

### 14. Service Dependencies and Timeouts
- **Current**: dbus-broker and display-manager have `restartIfChanged = lib.mkForce false` and long timeouts
- **Improvement**: 
  - Add proper dependency chains
  - Add health checks before dependent services start
  - Reduce timeout cascades
- **Benefit**: Stable switches, less cascading failures

### 15. Cron Job Optimization
- **Current**: Basic nix-collect-garbage, nix-store --optimise, journalctl vacuum
- **Improvement**: 
  - Add more frequent garbage collection
  - Add verification steps after optimisation
  - Add logging and monitoring of GC runs
- **Benefit**: Consistent store maintenance

## Usability Improvements

### 16. Hostname and Network Configuration
- **Current**: Basic networking, DNS via dnscrypt-proxy2 (commented out)
- **Improvement**: 
  - Add static hostname configuration
  - Add predictable network interface names
  - Configure /etc/hosts management
- **Benefit**: Consistent identification, easier networking

### 17. User Configuration Enhancements
- **Current**: User created with password "test" (hashed but still), groups configured
- **Improvement**: 
  - Remove default initial password
  - Add user encryption key setup
  - Add SSH authorized keys deployment
  - Add password policy configuration
- **Benefit**: Security, password management

### 18. Swap and Memory Management
- **Current**: Some vm.* parameters set
- **Improvement**: 
  - Configure zram or swap file with proper priorities
  - Add memory pressure handling
  - Add out-of-memory killer configuration
- **Benefit**: Better memory management, prevents OOM kills

### 19. Initrd Optimization
- **Current**: `systemd.enable = true` in initrd, `verbose = false`
- **Improvement**: 
  - Add early microcode loading
  - Add necessary modules for filesystem/driver support
  - Optimize initrd size with module stripping
- **Benefit**: Faster boots, more reliable early initialization

### 20. Systemd Service Management
- **Current**: dbus-broker timeout settings, cron, timesyncd enabled
- **Improvement**: 
  - Add service status monitoring
  - Add automatic restart on failure for critical services
  - Configure service watchdogs
- **Benefit**: Higher availability, faster recovery

### 21. Boot Configuration
- **Current**: systemd-boot with configurationLimit=10, some kernel params
- **Improvement**: 
  - Add boot timeout configuration
  - Add default entry configuration
  - Add boot image verification
  - Add recovery mode configuration
- **Benefit**: Faster boots, reliable recovery

### 22. DNS and Resolver Configuration
- **Current**: dnscrypt-proxy2 commented out, nameservers commented out
- **Improvement**: 
  - Enable and configure dnscrypt-proxy2 or alternative DNS-over-TLS
  - Configure /etc/resolv.conf management
  - Add DNSSEC enforcement
  - Add search domain configuration
- **Benefit**: Faster, more secure DNS resolution

### 23. Firewall Enhancement
- **Current**: `allowedTCPPorts = []`, `allowedUDPPorts = []` (completely open)
- **Improvement**: 
  - Add specific allowed services/ports
  - Add outbound firewall rules
  - Add connection tracking parameters
  - Add IPv6 specific rules
- **Benefit**: Reduced attack surface, network segmentation

### 24. Package Security
- **Current**: `allowUnfree = true`, `permittedInsecurePackages = ["mbedtls-2.28.10"]`
- **Improvement**: 
  - Reduce unfree packages where possible
  - Document why insecure packages are permitted
  - Add package signing verification
  - Move insecure packages to a separate channel
- **Benefit**: Better security posture, clearer trade-offs

### 25. Module Organization and Documentation
- **Current**: Modules spread across features/nixos/ with assay tests
- **Improvement**: 
  - Add module dependencies documentation
  - Add configuration options reference
  - Add migration guide for future changes
  - Add module assay documentation (already present)
- **Benefit**: Easier maintenance, clearer upgrade paths

## Modernization Improvements

### 26. Nix Options Modernization
- **Current**: Some deprecated/organizational nix options
- **Improvement**: 
  - Migrate to new Nix 3.0+ options where available
  - Add `nix.commandSupport` options
  - Add flake registry configuration
- **Benefit**: Future compatibility, new features

### 27. Module System Best Practices
- **Current**: Standard nix module system usage
- **Improvement**: 
  - Add module `configOptionHandling` for unknown options
  - Add `imports` with error handling
  - Add module `options` documentation
- **Benefit**: More robust module system, better error messages

### 28. Inputs and Flake Management
- **Current**: Basic flake inputs from nixpkgs and community
- **Improvement**: 
  - Add flake input pinning strategy
  - Add input override mechanism
  - Add flake registry with versions
- **Benefit**: Stable dependency management, reproducible environments

## Actions to Take

1. **Priority 1 (Security)**: Enable secure boot, add FDE, kernel hardening
2. **Priority 2 (Performance)**: Optimize build configs, GC, journal settings
3. **Priority 3 (Reliability)**: Improve service management, flake locking
4. **Priority 4 (Usability)**: Enhance user config, network, firewall
5. **Priority 5 (Modernization)**: Update nix options, module best practices

Each improvement should be implemented incrementally, with assays verified after each change to ensure compatibility.