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

## Verification
Run the verification script (see references/verify-moon-version.sh) or manually check the version.