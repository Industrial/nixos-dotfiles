---
name: nixos-improvements
category: system-administration
description: Class-level skill for documenting and tracking NixOS configuration improvements, optimizations, and best practices. This skill captures patterns, preferences, and proven configurations for NixOS setups excluding Home Manager. Organized by category with priority rankings and assay-verified changes.
---
# nixos-improvements

## Description
Class-level skill for documenting and tracking NixOS configuration improvements, optimizations, and best practices. This skill captures patterns, preferences, and proven configurations for NixOS setups excluding Home Manager. Organized by category with priority rankings and assay-verified changes.

## Improvements Framework

### Category: Security (Priority 1)
- Full Disk Encryption (FDE) with LUKS
- Secure Boot enablement
- Kernel hardening parameters
- AppArmor profiles for services
- SELinux consideration

### Category: Performance (Priority 2)
- Build parallelism optimization
- Binary cache expansion
- GC configuration tweaks
- Journal log management
- Initrd optimization

### Category: Reliability (Priority 3)
- Flake locking and input management
- Nix store optimization
- Service dependency management
- Cron job enhancements

### Category: Usability (Priority 4)
- User configuration enhancements
- Network/DNS setup (dnscrypt-proxy2)
- Firewall with specific rules
- Swap/memory management

### Category: Modernization (Priority 5)
- Nix 3.0+ option migration
- Module system best practices
- Flake input pinning
- Upgrade path documentation

## Verification

All improvements should be validated against existing NixOS assays before commitment. The assay system at `features/nixos/*/default.assay.nix` provides module-level shape validation.

## Related Skills

- `id-effect-migration` - For Rust/effect system migration patterns
- `hermes-plugin-authoring` - For Hermes Agent plugin development (if NixOS plugins needed)
- `maestro-design` - For product-spec authoring when NixOS changes affect broader workflows

## Associated Files

- `references/nixos-improvements-analysis.md` - Comprehensive improvements analysis
- `templates/` - Nix module starter templates
- `scripts/` - Verification and validation scripts

## Recent Changes (session-specific)

This skill captures NixOS configuration improvements learned during session work. Each improvement entry includes:
- Category and priority
- Current configuration state
- Proposed improvement
- Assay verification status
- Implementation notes

### Session 2026-08-15 Improvements

The following improvements were captured during the 2026-08-15 session:

#### FDE Implementation (Priority: Security)
- **File**: `features/nixos/fde/default.nix`
- **Change**: Added `boot.initrd.luks.devices` and `boot.initrd.luks.actions` for LUKS-encrypted root partition
- **Verification**: Assay structure validated; PR #107 open on GitHub
- **Notes**: LUKS encryption with initrd unlock support; file missing trailing newline (fixed in commit)

#### Secure Boot Implementation (Priority: Security)
- **File**: `features/nixos/secure-boot/default.nix`
- **Change**: Added `boot.loader.systemd-boot.enable`, `boot.loader.secureBoot.enable`, `boot.loader.efi.canTouchEfiVariables`
- **Verification**: Assay structure validated; PR #108 open on GitHub
- **Notes**: UEFI Secure Boot with systemd-boot configuration

#### NixOS Improvements Analysis (Priority: Modernization)
- **File**: `NIXOS_IMPROVEMENTS.md` (root repo, 239 lines)
- **Change**: Comprehensive 25-improvement analysis across 5 categories (Security, Performance, Reliability, Usability, Modernization)
- **Verification**: All module assays validated; PRs #107, #108, #109 open on GitHub
- **Notes**: Organized by priority; each improvement includes category, description, and implementation guidance

## Adding New Improvements

To add a new improvement:
1. Determine the category and priority
2. Write the improvement following the framework
3. Verify against existing assays
4. Document in `references/nixos-improvements-analysis.md`
5. Add entry to the improvements framework table