# Matching idclear/monorepo Feature Set in Other Projects

## Purpose
Guide for ensuring consistent tool availability across projects by matching the devenv feature set from the idclear/monorepo repository.

## Background
The idclear/monorepo repository serves as a reference for a fully-featured devenv setup with standard tools like Maestro, Claude Code, Context7 MCP server, etc. When working on other projects (like solana-yield-optimizer), it's useful to replicate this feature set to ensure consistent development experience.

## Comparing Feature Sets

### idclear/monorepo Enabled Features (from devenv.nix)
Based on inspection of `/data/Code/idclear/monorepo/devenv.nix`:

```nix
cursor.features = {
  program-moon = { enable = true; };
  program-lean-ctx = { enable = true; };
  program-roam-code = { enable = false; };
  program-roam-code-pypi = { enable = true; };
  program-context7 = { enable = true; };
  program-omniroute = { enable = true; };
  program-hermes = { enable = true; };
  program-maestro = { enable = true; };
  program-assay = { enable = true; };
  program-claude-code = { enable = true; };
  packages-base = { enable = true; };
  packages-formatters = { enable = true; };
  languages-javascript = { enable = true; };
  git-hooks-moon = { 
    enable = true;
    preCommitTargets = ":lint :test --affected remote --cache off";
    prePushTargets = ":lint :test :coverage :nix-test --affected remote --cache off";
  };
  git-hooks-prek = { enable = true; };
};
```

### Applying to solana-yield-optimizer
To match this feature set in `/data/Code/rust/solana-yield-optimizer/devenv.nix`:

1. **Ensure these are set to true**:
   ```nix
   cursor.features.program-maestro.enable = true;
   cursor.features.program-omniroute.enable = true;
   cursor.features.program-roam-code-pypi.enable = true;
   ```

2. **Note intentional differences**:
   - `program-roam-code`: idclear/monorepo has `false`, solana-yield-optimizer may want `true` for Rust navigation
   - Additional project-specific features may be needed (env-bindgen, languages-rust, etc.)

## Step-by-Step Matching Process

1. **Export idclear/monorepo feature list**:
   ```bash
   # From idclear/monorepo directory
   grep -o 'cursor\.features\.[a-zA-Z0-9\-]*\.enable\s*=\s*true' devenv.nix | cut -d. -f3 | sort > idclear-features.txt
   ```

2. **Export current project feature list**:
   ```bash
   # From solana-yield-optimizer directory
   grep -o 'cursor\.features\.[a-zA-Z0-9\-]*\.enable\s*=\s*true' devenv.nix | cut -d. -f3 | sort > current-features.txt
   ```

3. **Find missing features**:
   ```bash
   comm -23 <(sort idclear-features.txt) <(sort current-features.txt)
   ```

4. **Add missing features to devenv.nix**:
   Add lines like:
   ```nix
   cursor.features.<feature-name>.enable = true;
   ```

5. **Verify build works**:
   ```bash
   devenv shell --true  # Quick test
   devenv shell         # Full shell
   ```

## Specific Fixes Applied in This Session

In the solana-yield-optimizer repository, the following were added to match idclear/monorepo:

```nix
cursor.features.program-maestro.enable = true;
cursor.features.program-omniroute.enable = true;
cursor.features.program-roam-code-pypi.enable = true;
```

Additionally, the dotenv integration error was fixed by:
```nix
cursor.features.dotenv.enable = false;
```

And problematic package references were removed:
```nix
# Removed line that caused evaluation errors:
inputs.definitively.packages.${pkgs.stdenv.hostPlatform.system}.definitively
```

## Verification After Changes

After applying changes, verify:
1. `devenv shell` starts without errors
2. Expected tools are available:
   ```bash
   which maestro    # Should show maestro binary
   which claude     # Should show claude binary  
   which context7-mcp # Should show context7-mcp binary
   ```
3. Project-specific tools still work (cargo, rustc, etc.)

## Troubleshooting

If features don't work as expected:
1. Check that corresponding `.nix` files exist in `.cursor/nix/features/`
2. Verify no syntax errors in devenv.nix
3. Test features incrementally
4. Clear devenv cache with `devenv update` if needed

## Related Techniques
- See `references/solana-yield-optimizer-dotenv-fix.md` for dotenv-specific troubleshooting
- Use `devenv print-dev-env` to inspect the full configuration
- Use `devenv repl` to interactively inspect Nix expressions