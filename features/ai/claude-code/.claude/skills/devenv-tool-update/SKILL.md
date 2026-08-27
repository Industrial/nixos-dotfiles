---
name: devenv-tool-update
description: Update a tool defined in the .cursor/nix feature (e.g., moon).
version: 1
---

# Devenv Tool Update

## Overview
Update a tool (e.g., moon) defined in the .cursor/nix feature.

## Steps
1. Identify the feature Nix file (e.g., .cursor/nix/features/program-moon.nix).
2. Update the version and SHA256:
   - Fetch the new tarball URL.
   - Compute SHA256 with `nix-prefetch-url --type sha256 <URL>`.
   - Replace version and sha256 in the file.
3. Commit the change to the .cursor submodule:
   - `git add .cursor/nix/features/<feature>.nix`
   - `git commit -m "feat: update <tool> to <version>"`
   - Push the submodule: `cd .cursor && PREK_ALLOW_NO_CONFIG=1 git push`
4. Update the parent repository's submodule reference:
   - `cd .. && git add .cursor`
   - `git commit -m "feat: update <tool> to <version> in .cursor submodule"`
   - `git push`
5. Verify by entering a devenv shell and checking the tool version:
   - `devenv shell -- <tool> --version`

## Pitfalls
- Forgetting to push the submodule before updating the parent reference.
- Forgetting to set `PREK_ALLOW_NO_CONFIG=1` if the submodule lacks pre-commit config.
- Not updating the SHA256, leading to hash mismatch.
- Release-tarball tools (e.g. the assay-style `program-assay.nix` feature) pin an SRI hash, not a nix-prefetch SHA256: download the release tarball and use `nix hash file --sri --type sha256 <tarball>`. Wrapper-style variants of such features keep `releaseHash = null` deliberately — do not treat a null hash as stale.
- Fleet-wide rollout across repos (lockfiles, static pins, functional proof per consumer, commit policy) is governed by `devops/release-engineering` Part 3 — follow it instead of improvising a per-repo sweep.
- When devenv shell fails to start due to integration errors (e.g., dotenv integration requiring C-Nix devenv CLI), check `.cursor/nix/features/` for problematic feature flags and consider disabling them temporarily to isolate the issue.
- If MCP servers are unreachable, falling back to regular terminal commands (outside devenv shell) for inspection and basic fixes is acceptable when MCP tools persistently fail due to connectivity issues.

## Troubleshooting Common Devenv Issues
### Dotenv Integration Errors
If you see errors like:
```
error: The dotenv integration requires the C-Nix devenv CLI. It is not available through the flake integration or another standalone Nix evaluation.
```
This indicates the dotenv feature is enabled but the environment doesn't support it. Fix by disabling:
```nix
cursor.features.dotenv.enable = false;
```
in your `devenv.nix` file.

### MCP Server Connectivity Issues
When MCP servers (like lean-ctx) are persistently unreachable:
1. Verify the devenv environment is functional with `devenv shell -- true`
2. For file inspection/editing, use regular terminal commands (`cat`, `sed`, etc.) as a fallback
3. Restart the devenv environment: `devenv restart`
4. Check MCP server logs if available

### Specific Fix from Session
In the solana-yield-optimizer repository, the dotenv integration error was resolved by:
1. Setting `cursor.features.dotenv.enable = false;` in `devenv.nix`
2. Removing problematic definitively package references from `devenv.nix` that were causing evaluation errors

## Verification
Run the verification script (see references/verify-moon-version.sh) or manually check the version.