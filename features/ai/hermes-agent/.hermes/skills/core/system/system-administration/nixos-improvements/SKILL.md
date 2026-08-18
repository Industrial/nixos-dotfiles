---
name: nixos-improvements
category: system-administration
description: Class-level skill for documenting and tracking NixOS configuration improvements, optimizations, and best practices. This skill captures patterns, preferences, and proven configurations for NixOS setups excluding Home Manager. Organized by category with priority rankings and assay-verified changes.
---
## nixos-improvements

## Description
Class-level skill for documenting and tracking NixOS configuration improvements, optimizations, and best practices. This skill captures patterns, preferences, and proven configurations for NixOS setups excluding Home Manager. Organized by category with priority rankings and assay-verified changes.

## User Preferences\n- When making NixOS configuration changes, prefer using `hermes config set` over direct file edits when available, as per user preference due to security restrictions that block direct modifications to sensitive settings.\n- When adding new NixOS features or modules, verify they work correctly with `nixos-rebuild test` or `nixos-rebuild build` before switching to the new configuration.\n- User prefers concise, direct responses over verbose explanations.
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
- `references/safe-nixos-update-procedure.md` - Safe NixOS update procedures that preserve user sessions
- `templates/` - Nix module starter templates
  - `templates/feature-structure.md` - Standard structure for NixOS features
- `scripts/` - Verification and validation scripts

## Recent Changes (session-specific)

This skill captures NixOS configuration improvements learned during session work. Each improvement entry includes:
- Category and priority
- Current configuration state
- Proposed improvement
- Assay verification status
- Implementation notes

### Session 2026-08-18 Improvements

The following improvements were captured during the 2026-08-18 session:

#### Safe NixOS Update Practices (Priority: Reliability)
- **Files**: 
  - `features/cli/nixos-update-notifier/default.nix` (new feature)
  - `features/nixos/auto-update/default.nix` (disabled auto-update)
  - `hosts/drakkar/flake.nix` (added nixos-update-notifier-src)
- **Changes**:
  - Added user-level nixos-update-notifier feature for checking updates and sending notifications
  - Disabled root auto-update service to prevent automatic reboots that could kill user sessions
  - Added nixos-update-notifier source to flake inputs
- **Verification**: All module assays validated
- **Notes**: 
  - User timer runs in user space, only checks for updates and sends desktop notifications
  - Auto-update disabled prevents background updates that might trigger reboots
  - Following these practices allows safe NixOS configuration updates without killing user sessions
  - Safe update procedure: 
    1. `nix flake update` to see what would change
    2. `nix build .#hostname` to test compilation
    3. `sudo nixos-rebuild switch --flake .#hostname` to apply changes (only restarts services if necessary)

#### Session 2026-08-15 Improvements (Previously Recorded)

The following improvements were captured during the 2026-08-15 session:

#### FDE Implementation (Priority: Security)
- **File**: `features/nixos/fde/default.nix`
- **Change**: Added `boot.initrd.luks.devices` and `boot.initrd.luks.actions` for LUKS-encrypted root partition
- **Verification**: Assay structure validated; PR #107 open on GitHub
- **Notes**: LUKS encryption with initrd unlock support; file missing trailing newline (fixed in commit)

#### Secure Boot Implementation (Priority: Security)\n- **File**: `features/nixos/secure-boot/default.nix`\n- **Change**: Added `boot.loader.systemd-boot.enable`, `boot.loader.secureBoot.enable`, `boot.loader.efi.canTouchEfiVariables`\n- **Verification**: Assay structure validated; PR #108 open on GitHub\n- **Notes**: UEFI Secure Boot with systemd-boot configuration. Now enabled in base profile for all hosts.

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
4. Document in `references/nixos-improvements-analysis.md` or `references/safe-nixos-update-procedure.md` (for update procedures)
5. Add entry to the improvements framework table

## Standard NixOS Feature Structure

For features in `features/<category>/<name>/` (cli, nixos, etc.):

### Required Files
- `package.nix` - Defines the package using appropriate builders (buildRustPackage, etc.)
- `default.nix` - Includes the package in environment.systemPackages or appropriate NixOS module options

### Optional Files
- `default.assay.nix` - Assay unit tests for the feature

### Standard Patterns

**package.nix** (for Rust packages):
```nix
{ lib, pkgs, ... }: 
  pkgs.buildRustPackage rec {
    pname = "<featurename>";
    version = "<version>";

    src = pkgs.fetchFromGitHub {
      owner = "<owner>";
      repo = "<repo>";
      rev = "<rev>";
      sha256 = "<sha256>";
    };

    # ... other package configuration

    meta = {
      description = "<description>";
      homepage = "<homepage>";
      license = lib.licenses.<license>;
      platforms = pkgs.platforms.linux;
      maintainers = [pkgs.maintainers.unknown];
    };
  }
```

**default.nix**:
```nix
{ lib, pkgs, ... }:
{
  environment.systemPackages = [ (pkgs.callPackage ./package.nix {}) ];
}
```

**default.assay.nix**:
```nix
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {
      <featurename> = "<featurename>";
    };
  in
    import ./default.nix {inherit pkgs;};
in
  assay.suite "<featurename>" {
    systemPackages = assay.eq mod.environment.systemPackages ["<featurename>"];
  }
```
See `templates/feature-structure.md` for a reference.