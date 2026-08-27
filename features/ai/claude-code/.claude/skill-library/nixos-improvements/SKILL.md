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

### Category: Usability (Priority 4)\n- User configuration enhancements\n- Network/DNS setup (dnscrypt-proxy2)\n- Firewall with specific rules\n- Swap/memory management\n- Desktop application environment troubleshooting (e.g., Lutris/Steam environment inheritance)\n
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

## Associated Files\n\n- `references/nixos-improvements-analysis.md` - Comprehensive improvements analysis\n- `references/safe-nixos-update-procedure.md` - Safe NixOS update procedures that preserve user sessions\n- `scripts/verify-host-config-consistency.sh` - Bash script to verify host flake.nix consistency\n- `references/lutris-steam-environment-troubleshooting.md` - Troubleshooting guide for Lutris/Steam environment inheritance issues
- `references/assay-suite-authoring.md` - Authoring colocated assay suites: claim-semantics gotchas, module/package/generated-file skeletons, sensitive-data rules, gap-inventory method

### Session 2026-08-23: Assay-Gap Unit-Test Coverage
Closed every tracked `.nix` file lacking a `<stem>.assay.nix` complement (7 new suites; full gate 582/582). Key learnings captured in `references/assay-suite-authoring.md`:
- **Filter inventories to git-tracked files** (`git ls-files --error-unmatch`) — devenv state dirs and nested runtime trees otherwise produce false gaps.
- **Check HEAD-vs-worktree drift before rewriting**: a suite can exist at HEAD but be deleted locally (homarr, d1445335); when superseding, preserve every original assertion.
- **`.hermes/` trees are off limits** for test/helper files (user directive) — hermes plugin templates stay exempt from assay coverage; record exemptions in the repo `history/` ledger.
- **Repo hooks outside devenv shell**: meta hooks named literally `pre-commit`/`pre-push` fail ENOENT after real gates pass; use `SKIP=pre-commit` / `SKIP=pre-push` or operate from `devenv shell`.

## Recent Changes (session-specific)

This skill captures NixOS configuration improvements learned during session work. Each improvement entry includes:
- Category and priority
- Current configuration state
- Proposed improvement
- Assay verification status
- Implementation notes

### Session 2026-08-21 Improvements

The following improvements were captured during the 2026-08-21 session:

#### Enabling Shared Features via Profile Imports (Priority: Reliability)
- **File**: `profiles/development.nix`
- **Change**: Uncommented `../features/programming/neovim` import line
- **Impact**: Enabled NeoVim on all three hosts (Drakkar, Mimir, Huginn) through the profile inheritance chain
- **Inheritance chains verified**:
  - Drakkar: `hosts/drakkar/configuration.nix` → `profiles/development.nix`
  - Mimir: `hosts/mimir/configuration.nix` → `profiles/server.nix` → `profiles/development.nix`
  - Huginn: `hosts/huginn/configuration.nix` → `profiles/mobile.nix` → `profiles/development.nix`
- **Verification**: Ad-hoc script verified import is uncommented, all inheritance chains trace correctly, and the neovim feature module has `programs.nixvim.enable = true` (5/5 checks passed)
- **Notes**: When a feature is imported in a shared profile (base, development, desktop, etc.) it cascades to every host that inherits that profile. This is the most efficient way to enable a feature fleet-wide with a single change. Always verify the complete inheritance chain for each target host before and after the change.

#### Nixvim Plugin Version Conflict: Legacy Treesitter Refactor Removal (Priority: Modernization)
- **File**: `features/programming/neovim/language-support.nix`
- **Change**: Removed `treesitter-refactor` plugin module; kept `treesitter` (new main-branch module) and `treesitter-context`
- **Root cause**: `treesitter-refactor` is a legacy nvim-treesitter consumer that bundles its own copy of the old `nvim-treesitter` package, conflicting with the new main-branch `treesitter` module. Error: "You cannot include two different versions of nvim-treesitter, perhaps you included a legacy plugin together with a new one?"
- **Fix**: Removed the `treesitter-refactor = { enable = true; };` block entirely; added a comment documenting why
- **Verification**: `nix flake check --impure` error changed from the treesitter conflict to an unrelated pre-existing sphinx/python error, confirming the conflict was resolved. Assay tests for `neovim` and `language-support` still pass (2/2 each)
- **Upstream reference**: https://github.com/nix-community/nixvim/issues/4188 — nixvim maintainers confirmed: "The short-term fix is to disable that plugin or otherwise avoid mixing the new nvim-treesitter package with legacy consumers"
- **Key takeaway**: When enabling nixvim features, inspect all plugin configurations for legacy nvim-treesitter consumers. The new `treesitter` module uses Neovim's native treesitter APIs; legacy plugins that call `require('nvim-treesitter.configs').setup()` will conflict. Use `git stash` + `nix flake check` before/after to isolate whether an error is from your change or pre-existing.

### Session 2026-08-19 Improvements

The following improvements were captured during the 2026-08-19 session:

#### Standardizing Host Configurations in NixOS Flakes (Priority: Reliability)
- **Files**: 
  - `hosts/huginn/flake.nix`
  - `hosts/mimir/flake.nix` 
  - `hosts/drakkar/flake.nix`
- **Changes**:
  - Standardized feature lists across all host flake.nix files to have the same features in the same order
  - Preserved each host's specific commenting/uncommenting choices
  - Enabled Hyprland window manager for huginn host (uncommented `../../features/window-manager/hyprland`)
  - Kept Hyprland commented out for mimir and drakkar hosts
- **Verification**: 
  - Verified all hosts have identical feature keys in the same order (62 features)
  - Confirmed Hyprland is properly uncommented for huginn only
  - Used ad-hoc verification scripts to check syntax and consistency
- **Notes**: 
  - This approach allows maintaining a common baseline while preserving host-specific customizations
  - Makes it easier to track differences between hosts
  - Simplifies updating common features across all hosts
  - Verification procedure: extract feature keys (stripping comments) and compare ordered lists

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
## Recent Changes (session-specific)

This skill captures NixOS configuration improvements learned during session work. Each improvement entry includes:
- Category and priority
- Current configuration state
- Proposed improvement
- Assay verification status
- Implementation notes

### Session 2026-08-21 Improvements

The following improvements were captured during the 2026-08-21 session:

#### Enabling Shared Features via Profile Imports (Priority: Reliability)
- **File**: `profiles/development.nix`
- **Change**: Uncommented `../features/programming/neovim` import line
- **Impact**: Enabled NeoVim on all three hosts (Drakkar, Mimir, Huginn) through the profile inheritance chain
- **Inheritance chains verified**:
  - Drakkar: `hosts/drakkar/configuration.nix` → `profiles/development.nix`
  - Mimir: `hosts/mimir/configuration.nix` → `profiles/server.nix` → `profiles/development.nix`
  - Huginn: `hosts/huginn/configuration.nix` → `profiles/mobile.nix` → `profiles/development.nix`
- **Verification**: Ad-hoc script verified import is uncommented, all inheritance chains trace correctly, and the neovim feature module has `programs.nixvim.enable = true` (5/5 checks passed)
- **Notes**: When a feature is imported in a shared profile (base, development, desktop, etc.) it cascades to every host that inherits that profile. This is the most efficient way to enable a feature fleet-wide with a single change. Always verify the complete inheritance chain for each target host before and after the change.

#### Nixvim Plugin Version Conflict: Legacy Treesitter Refactor Removal (Priority: Modernization)
- **File**: `features/programming/neovim/language-support.nix`
- **Change**: Removed `treesitter-refactor` plugin module; kept `treesitter` (new main-branch module) and `treesitter-context`
- **Root cause**: `treesitter-refactor` is a legacy nvim-treesitter consumer that bundles its own copy of the old `nvim-treesitter` package, conflicting with the new main-branch `treesitter` module. Error: "You cannot include two different versions of nvim-treesitter, perhaps you included a legacy plugin together with a new one?"
- **Fix**: Removed the `treesitter-refactor = { enable = true; };` block entirely; added a comment documenting why
- **Verification**: `nix flake check --impure` error changed from the treesitter conflict to an unrelated pre-existing sphinx/python error, confirming the conflict was resolved. Assay tests for `neovim` and `language-support` still pass (2/2 each)
- **Upstream reference**: https://github.com/nix-community/nixvim/issues/4188 — nixvim maintainers confirmed: "The short-term fix is to disable that plugin or otherwise avoid mixing the new nvim-treesitter package with legacy consumers"
- **Key takeaway**: When enabling nixvim features, inspect all plugin configurations for legacy nvim-treesitter consumers. The new `treesitter` module uses Neovim's native treesitter APIs; legacy plugins that call `require('nvim-treesitter.configs').setup()` will conflict. Use `git stash` + `nix flake check` before/after to isolate whether an error is from your change or pre-existing.

### Session 2026-08-19 Improvements

The following improvements were captured during the 2026-08-19 session:

#### Standardizing Host Configurations in NixOS Flakes (Priority: Reliability)
- **Files**: 
  - `hosts/huginn/flake.nix`
  - `hosts/mimir/flake.nix` 
  - `hosts/drakkar/flake.nix`
- **Changes**:
  - Standardized feature lists across all host flake.nix files to have the same features in the same order
  - Preserved each host's specific commenting/uncommenting choices
  - Enabled Hyprland window manager for huginn host (uncommented `../../features/window-manager/hyprland`)
  - Kept Hyprland commented out for mimir and drakkar hosts
- **Verification**: 
  - Verified all hosts have identical feature keys in the same order (62 features)
  - Confirmed Hyprland is properly uncommented for huginn only
  - Used ad-hoc verification scripts to check syntax and consistency
- **Notes**: 
  - This approach allows maintaining a common baseline while preserving host-specific customizations
  - Makes it easier to track differences between hosts
  - Simplifies updating common features across all hosts
  - Verification procedure: extract feature keys (stripping comments) and compare ordered lists

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
## Recent Changes (session-specific)

This skill captures NixOS configuration improvements learned during session work. Each improvement entry includes:
- Category and priority
- Current configuration state
- Proposed improvement
- Assay verification status
- Implementation notes

### Session 2026-08-21 Improvements

The following improvements were captured during the 2026-08-21 session:

#### Enabling Shared Features via Profile Imports (Priority: Reliability)
- **File**: `profiles/development.nix`
- **Change**: Uncommented `../features/programming/neovim` import line
- **Impact**: Enabled NeoVim on all three hosts (Drakkar, Mimir, Huginn) through the profile inheritance chain
- **Inheritance chains verified**:
  - Drakkar: `hosts/drakkar/configuration.nix` → `profiles/development.nix`
  - Mimir: `hosts/mimir/configuration.nix` → `profiles/server.nix` → `profiles/development.nix`
  - Huginn: `hosts/huginn/configuration.nix` → `profiles/mobile.nix` → `profiles/development.nix`
- **Verification**: Ad-hoc script verified import is uncommented, all inheritance chains trace correctly, and the neovim feature module has `programs.nixvim.enable = true` (5/5 checks passed)
- **Notes**: When a feature is imported in a shared profile (base, development, desktop, etc.) it cascades to every host that inherits that profile. This is the most efficient way to enable a feature fleet-wide with a single change. Always verify the complete inheritance chain for each target host before and after the change.

#### Nixvim Plugin Version Conflict: Legacy Treesitter Refactor Removal (Priority: Modernization)
- **File**: `features/programming/neovim/language-support.nix`
- **Change**: Removed `treesitter-refactor` plugin module; kept `treesitter` (new main-branch module) and `treesitter-context`
- **Root cause**: `treesitter-refactor` is a legacy nvim-treesitter consumer that bundles its own copy of the old `nvim-treesitter` package, conflicting with the new main-branch `treesitter` module. Error: "You cannot include two different versions of nvim-treesitter, perhaps you included a legacy plugin together with a new one?"
- **Fix**: Removed the `treesitter-refactor = { enable = true; };` block entirely; added a comment documenting why
- **Verification**: `nix flake check --impure` error changed from the treesitter conflict to an unrelated pre-existing sphinx/python error, confirming the conflict was resolved. Assay tests for `neovim` and `language-support` still pass (2/2 each)
- **Upstream reference**: https://github.com/nix-community/nixvim/issues/4188 — nixvim maintainers confirmed: "The short-term fix is to disable that plugin or otherwise avoid mixing the new nvim-treesitter package with legacy consumers"
- **Key takeaway**: When enabling nixvim features, inspect all plugin configurations for legacy nvim-treesitter consumers. The new `treesitter` module uses Neovim's native treesitter APIs; legacy plugins that call `require('nvim-treesitter.configs').setup()` will conflict. Use `git stash` + `nix flake check` before/after to isolate whether an error is from your change or pre-existing.

### Session 2026-08-19 Improvements

The following improvements were captured during the 2026-08-19 session:

#### Standardizing Host Configurations in NixOS Flakes (Priority: Reliability)
- **Files**: 
  - `hosts/huginn/flake.nix`
  - `hosts/mimir/flake.nix` 
  - `hosts/drakkar/flake.nix`
- **Changes**:
  - Standardized feature lists across all host flake.nix files to have the same features in the same order
  - Preserved each host's specific commenting/uncommenting choices
  - Enabled Hyprland window manager for huginn host (uncommented `../../features/window-manager/hyprland`)
  - Kept Hyprland commented out for mimir and drakkar hosts
- **Verification**: 
  - Verified all hosts have identical feature keys in the same order (62 features)
  - Confirmed Hyprland is properly uncommented for huginn only
  - Used ad-hoc verification scripts to check syntax and consistency
- **Notes**: 
  - This approach allows maintaining a common baseline while preserving host-specific customizations
  - Makes it easier to track differences between hosts
  - Simplifies updating common features across all hosts
  - Verification procedure: extract feature keys (stripping comments) and compare ordered lists

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

#### Secure Boot Implementation (Priority: Security)
- **File**: `features/nixos/secure-boot/default.nix`
- **Change**: Added `boot.loader.systemd-boot.enable`, `boot.loader.secureBoot.enable`, `boot.loader.efi.canTouchEfiVariables`
- **Verification**: Assay structure validated; PR #108 open on GitHub
- **Notes**: UEFI Secure Boot with systemd-boot configuration. **Enabled in base profile** (commit 5756c304) making it active for all hosts (drakkar, huginn, mimir) upon next rebuild.

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

## Standardizing Host Configurations Technique

When managing multiple hosts with similar NixOS configurations, standardizing feature lists improves maintainability:

1. **Select a reference host** (typically the one with the most complete feature set)
2. **Extract normalized feature keys** from the reference:
   - For each line in the module block, strip whitespace and leading '#' 
   - Ignore empty lines
   - Maintain original order
3. **Process each target host**:
   - Parse the module block to map feature keys to existing lines
   - For each feature in reference order:
     * Use host's existing line if present (preserves comment status)
     * Add missing features as commented out lines
   ## Adding New Improvements

   To add a new improvement:
   1. Determine the category and priority
   2. Write the improvement following the framework
   3. Verify against existing assays
   4. Document in `references/nixos-improvements-analysis.md` or `references/safe-nixos-update-procedure.md` (for update procedures)
   5. Add entry to the improvements framework table

   ## Standardizing Host Configurations Technique

   When managing multiple hosts with similar NixOS configurations, standardizing feature lists improves maintainability while preserving host-specific customizations.

   ### Procedure

   1. **Select a Reference Host**
      - Choose the host with the most complete feature set as your baseline
      - Typically the host that represents your standard configuration

   2. **Extract Normalized Feature Keys from Reference**
      - For each line in the module block (`modules = [` to `];`):
        * Strip leading and trailing whitespace
        * If line starts with '#', remove the comment marker and any whitespace after it
        * Ignore empty lines
        * Keep the remaining text as the feature key
      - Maintain the original order of features

   3. **Process Each Target Host**
      - Parse the template host's module block to create a mapping of feature keys to existing lines
      - For each feature in the reference order:
        * If the host already has a line for this feature (commented or uncommented), preserve that line exactly as-is
        * If the host is missing a line for this feature, add it as a commented-out line
      - Preserve the host's original indentation style for the module block

   4. **Verify Host-Specific Requirements**
      - Check that host-specific features are properly configured (e.g., window managers, hardware-specific settings)
      - Ensure no required features are accidentally commented out

   ### Verification Methods

   **Manual Verification:**
   - Extract feature keys from each host (stripping comments and whitespace)
   - Compare the ordered lists - they should be identical
   - Check specific features' comment status as needed per host requirements

   **Automated Verification Script Pattern:**
   ```bash
   # Verify all hosts have same features in same order
   host1_keys=$(grep -A 20 "modules = \[" host1/flake.nix | grep -E "^\s*(#.*)?$" | sed 's/^\s*#\?\s*//' | grep -v "^$")
   host2_keys=$(grep -A 20 "modules = \[" host2/flake.nix | grep -E "^\s*(#.*)?$" | sed 's/^\s*#\?\s*//' | grep -v "^$")
   [ "$host1_keys" = "$host2_keys" ] && echo "Feature lists match" || echo "Feature lists differ"

   # Verify specific feature is uncommented in particular host
   grep -n "feature_path" host/flake.nix | grep -v "^\s*#" && echo "Feature enabled" || echo "Feature disabled or missing"
   ```

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
     };
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
     };
   ```
   See `templates/feature-structure.md` for a reference.

   ## User Preferences Embedded

   - When making NixOS configuration changes, prefer using `hermes config set` over direct file edits when available, as per user preference due to security restrictions that block direct modifications to sensitive settings.
   - When adding new NixOS features or modules, verify they work correctly with `nixos-rebuild test` or `nixos-rebuild build` before switching to the new configuration.
   - User prefers concise, direct responses over verbose explanations.
   - When standardizing configurations across multiple hosts, extract feature keys (stripping comments and whitespace) to compare ordered lists, preserving each host's specific commenting/uncommenting choices.
   - When verifying NixOS configuration changes, use ad-hoc verification scripts to check specific requirements rather than relying solely on full rebuilds when appropriate.