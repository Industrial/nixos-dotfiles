---
name: nixos-codebase-analysis
description: |
  Analyze a NixOS dotfiles repository and produce structured improvement analyses.
  Research the codebase structure, compare against best practices, and produce
  organized lists of improvements across security, performance, reliability,
  usability, and modernization categories.
skill_class: nixos-analysis
---

# NixOS Codebase Analysis Skill

**When to use:** When researching a NixOS codebase structure, identifying configuration patterns, or producing improvement analyses for NixOS setups.

**Triggers:**
- User asks to "research our NixOS setup and compare it to status quo"
- User asks to "make a big list of improvements" for NixOS configuration
- User asks to "analyze the NixOS configuration and identify areas for improvement"
- User asks to "review NixOS modules and assess their completeness"

## How to Execute

### Step 1: Explore Repository Structure
- List top-level directories and feature areas
- Identify the profile system and how modules are composed
- Locate main `default.nix` and profile files
- Check for assay/validation files in each module directory

### Step 2: Read Key Configuration Files
- Read the main `default.nix` for core NixOS settings
- Read `default.assay.nix` files in each module directory to understand validation patterns
- Read profile files (under `profiles/`) to understand module composition
- Read individual feature module files under `features/nixos/*/`

### Step 3: Run Verification
- Execute assays to confirm current configuration state
- Note which modules pass/fail validation
- Document any errors or warnings from evaluation

### Step 4: Produce Improvements List
Organize improvements into these categories (Priority order):

1. **Security (Priority 1)**
   - Full Disk Encryption (FDE) setup
   - Secure Boot enablement  
   - Kernel hardening parameters
   - AppArmor profiles for services
   - Package security review

2. **Performance (Priority 2)**
   - Build parallelism optimization
   - Binary cache expansion
   - Garbage collection configuration
   - Journal log management
   - Initrd optimization

3. **Reliability (Priority 3)**
   - Flake locking and input management
   - Nix store optimization
   - Service dependency management
   - Cron job enhancements
   - Build timeout tuning

4. **Usability (Priority 4)**
   - User configuration enhancements
   - Network/DNS setup
   - Firewall with specific rules
   - Swap/memory management
   - Boot configuration improvements

5. **Modernization (Priority 5)**
   - Nix 3.0+ option migration
   - Module system best practices
   - Flake input pinning strategy
   - New Nix options adoption

### Step 5: Document and Verify
- Write findings to `NIXOS_IMPROVEMENTS.md`
- Verify existing assays still pass
- Note assay constraints and limitations
- Provide recommended implementation order

## Output

Produces a comprehensive markdown document at `NIXOS_IMPROVEMENTS.md` containing:
- Overview of current NixOS setup
- Analysis across 5 priority categories with ~25 specific improvement items
- Rationale for each improvement
- Verification status against existing assays
- Recommended implementation sequence

## Session Reference\n\nThis skill was used in a session that produced `/home/tom/.dotfiles/NIXOS_IMPROVEMENTS.md` — a 239-line analysis of the NixOS setup under `/home/tom/.dotfiles/features/nixos/`, examining 11 module directories and producing 25 improvement items across 5 priority categories (Security, Performance, Reliability, Usability, Modernization). The session also implemented Full Disk Encryption (FDE) configuration at `features/nixos/fde/default.nix` with `boot.initrd.luks.devices` and `boot.initrd.luks.actions` for LUKS-encrypted root partition support.\n\n## Related Skills\n
- `skill-library-structure` — For organizing skills within the project convention
- `web-research-techniques` — For research pattern guidance when extending beyond the local codebase
- `hermes-plugin-authoring` — For adding NixOS-specific plugins if needed

## Pitfalls to Avoid

- ❌ Don't modify another profile's skills/plugins/cron/memories without explicit direction
- ❌ Don't assume Home Manager is available — the user explicitly excludes it
- ❌ Don't create improvements that break existing assays without mitigation
- ❌ Don't produce generic "best practice" lists without referencing the actual codebase
- ❌ Don't skip the verification step — always run assays after proposed changes