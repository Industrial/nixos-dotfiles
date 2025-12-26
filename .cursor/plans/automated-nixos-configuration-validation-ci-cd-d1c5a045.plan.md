<!-- d1c5a045-1722-49c0-af5c-b393185f5eb6 b09d4abe-0a9d-4654-b218-871beba035ee -->
# Automated NixOS Configuration Validation CI/CD Plan

## Overview

Implement automated NixOS configuration validation using treefmt in GitHub Actions. This will ensure all configuration files are properly formatted before PRs can be merged, maintaining code quality and consistency across all hosts.

## Architecture

The CI/CD pipeline will:

1. Run on every pull request
2. Use devenv to provide all required formatters (treefmt, alejandra, deadnix, etc.)
3. Execute treefmt with `treefmt.ci.toml` configuration
4. Fail the check if any formatting issues are detected
5. Block PR merges until formatting passes

## Implementation

### Phase 1: GitHub Actions Workflow Setup

**Create `.github/workflows/format-check.yml`**

This workflow will:

- Trigger on `pull_request` events
- Install Nix using `cachix/install-nix-action`
- Install devenv
- Run treefmt using devenv shell with `treefmt.ci.toml` config
- Fail if any formatting issues are found

**Key components:**

- Use `cachix/install-nix-action@v31` for Nix installation
- Install devenv via nix-env or nix profile
- Run: `devenv shell -- treefmt --config-file treefmt.ci.toml`
- The `treefmt.ci.toml` already has `fail-on-change = true` which will cause treefmt to exit with error if changes are needed

### Phase 2: Branch Protection Configuration

**Set up branch protection rules using GitHub CLI (`gh`)**

Configure the `main` branch to:

- Require the "Format Check" workflow to pass before merging
- Prevent direct pushes to main (require PRs)
- Require status checks to pass

**Commands to execute:**

```bash
gh api repos/:owner/:repo/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["Format Check"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":0}' \
  --field restrictions=null
```

Or use the simpler approach:

```bash
gh api repos/:owner/:repo/branches/main/protection \
  --method PUT \
  -f required_status_checks='{"strict":true,"contexts":["Format Check"]}' \
  -f enforce_admins=true \
  -f required_pull_request_reviews=null \
  -f restrictions=null
```

**Note:** The repository owner/name will need to be determined at runtime.

### Phase 3: Verification

**Test the workflow:**

1. Create a test PR with intentionally bad formatting
2. Verify the workflow fails
3. Fix formatting and verify the workflow passes
4. Verify PR merge is blocked until workflow passes

## Files to Create

- `.github/workflows/format-check.yml` - GitHub Actions workflow for format checking

## Files to Modify

- None (all configuration already exists: `treefmt.ci.toml`, `devenv.nix`)

## Implementation Details

### GitHub Actions Workflow Structure

```yaml
name: Format Check

on:
  pull_request:
    branches: [main]

jobs:
  format-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: cachix/install-nix-action@v31
        with:
          nix_path: nixpkgs=channel:nixos-unstable
      
      - name: Install devenv
        run: nix profile install github:cachix/devenv
      
      - name: Run treefmt
        run: devenv shell -- treefmt --config-file treefmt.ci.toml
```

### Branch Protection Setup

The branch protection will be configured using `gh` CLI commands that:

- Set the "Format Check" workflow as a required status check
- Enable strict status checks (all must pass)
- Enforce protection for admins
- Allow PRs but require status checks to pass

## Success Criteria

- Format Check workflow runs on every PR
- Workflow fails if formatting issues are detected
- Workflow passes if all files are properly formatted
- PR merges are blocked when workflow fails
- Branch protection prevents direct pushes to main
- All formatters from `treefmt.ci.toml` are available via devenv

## Risks & Considerations

- **Devenv installation time**: Installing devenv in CI may add time to workflow runs
- **Formatter availability**: Ensure all formatters in `treefmt.ci.toml` are available in devenv (already verified in `devenv.nix`)
- **GitHub CLI authentication**: Need to ensure `gh` CLI is authenticated before running branch protection commands
- **Repository permissions**: Need appropriate permissions to set branch protection rules

## Future Enhancements

- Add Nix evaluation checks (`nix flake check`)
- Add dry-run builds for all hosts
- Add caching for devenv/nix store
- Add matrix strategy to validate each host separately
- Add PR comments with formatting suggestions

### To-dos

- [ ] Create .github/workflows/format-check.yml with GitHub Actions workflow for format checking
- [ ] Test the workflow locally or on a test branch to ensure it works correctly
- [ ] Configure branch protection rules using gh CLI commands to require Format Check workflow
- [ ] Create a test PR with bad formatting and verify merge is blocked until formatting is fixed