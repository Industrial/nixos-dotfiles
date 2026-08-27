---
name: devenv-troubleshooting
description: Troubleshooting devenv shell integration issues, particularly dotenv module conflicts and package resolution problems
---

# Devenv Troubleshooting

## Purpose
Resolve common devenv shell startup failures, particularly those related to:
- dotenv integration requiring C-Nix devenv CLI
- Package reference errors (like definitively)
- Shell evaluation failures due to misconfigured features

## When to Use
- devenv shell fails with "The dotenv integration requires the C-Nix devenv CLI" error
- devenv shell fails during package evaluation with missing attribute errors
- Shell startup fails after modifying devenv.nix configuration
- Need to selectively disable devenv features to isolate problems

## Steps

### 1. Identify the Error Pattern
Look for these common failure patterns in devenv shell output:
- `The dotenv integration requires the C-Nix devenv CLI. It is not available through the flake integration`
- Evaluation errors referencing `dotenv.nix` modules
- Missing attribute errors like `attribute 'definitively' missing`
- Failed derivation due to `removeAttrs` or `mapAttrs` builtins

### 2. Disable Problematic Features Temporarily
To isolate issues, selectively disable devenv features in your `devenv.nix`:

```nix
# In devenv.nix, set problematic features to false:
cursor.features.dotenv.enable = false;
# Add others as needed based on error context
```

### 3. Remove Problematic Package References
If errors reference missing packages (like definitively):

1. Check if the package is defined in your `.cursor/nix/` features:
   ```bash
   ls -la .cursor/nix/features/ | grep -i definitively
   ```
2. If not found, remove the reference from `devenv.nix`:
   ```nix
   # Remove lines like:
   inputs.definitively.packages.${pkgs.stdenv.hostPlatform.system}.definitively
   ```

### 4. Verify .envrc Doesn't Conflict
Ensure your `.envrc` isn't interfering with devenv:
- devenv manages environment loading automatically
- Conflicting `.envrc` directives can cause evaluation issues
- Consider renaming `.envrc` to `.envrc.bak` temporarily to test

### 5. Test Incrementally
After making changes:
```bash
devenv shell --command "echo 'shell works'"
# or just
devenv shell
# Then exit with Ctrl+D when ready
```

### 6. Re-enable Features Systematically
Once base shell works, re-enable features one by one:
1. Enable a feature
2. Test `devenv shell`
3. If fails, that feature needs specific configuration
4. Continue with next feature

## Specific Fixes

### Fixing dotenv Integration Errors
When seeing: "The dotenv integration requires the C-Nix devenv CLI"

**Root Cause**: The dotenv module tries to load `devenvPrimops.loadDotenv` which only exists in the C-Nix devenv CLI, not in pure Nix evaluation.

**Solution**: Either:
- Disable the dotenv feature: `cursor.features.dotenv.enable = false;`  
- Or ensure you're using the proper devenv CLI (not evaluating as flake)

### Fixing Missing Package References
When seeing errors like: `attribute 'definitively' missing`

**Root Cause**: Referencing a package/input that isn't defined in your devenv.yaml inputs.

**Solution**:
1. Add the missing input to `devenv.yaml` under `inputs:`
2. OR remove the reference if the package isn't needed
3. Check `.cursor/nix/features/` for corresponding `.nix` files

## Pitfalls

### Common Mistakes
- **Assuming all .cursor/nix features are safe to enable**: Some features depend on specific inputs or system configurations
- **Not checking if referenced packages actually exist**: Leads to evaluation errors
- **Overlooking that devenv evaluates modules lazily**: Errors may appear far from the actual cause
- **Forgetting that some features conflict**: dotenv and manual .env loading can conflict

### Environment-Specific Issues
- **Flake vs CLI evaluation**: Some modules only work in devenv CLI context
- **System-specific packages**: Referencing packages that don't exist on your platform
- **Cached evaluations**: Old errors may persist until you clear caches with `devenv update`

## Verification
After fixing issues, verify:
1. `devenv shell` starts successfully
2. Expected tools are in PATH (e.g., `which claude`, `which python`)
3. Environment variables are set correctly (`devenv printenv` or `devenv shell --command "env"`)
4. Project-specific initialization works (enterShell hooks run)

## Related Skills
- `hermes-environment-replication`: For copying working devenv setups between projects
- `hermes-configuration-management`: For managing devenv configuration via hermes CLI
- `skill-library-structure`: For understanding how to organize troubleshooting knowledge

## References
- `references/solana-yield-optimizer-dotenv-fix.md` - Detailed walkthrough of fixing dotenv integration error in solana-yield-optimizer repository
- `references/fish-rehash.md` - Details on fixing the fish shell command hashing issue.
- `references/claude-code-provisioning.md` - Detailed steps for provisioning Claude Code after copying .claude setup.
- `references/matching-idclear-monorepo-features.md` - Guide for matching feature set between projects to ensure consistent tool availability

## Change Log
- Initial capture from session fixing dotenv integration error in solana-yield-optimizer repository
- Added patterns for disabling features and removing problematic package references
- Added guidance for matching feature sets between projects to ensure consistent tool availability