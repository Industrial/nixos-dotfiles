---
name: devenv-submodule-handling
description: Handle devenv environments when using git submodules (e.g., .cursor/setup) to avoid "not tracked by Git" errors.
---

Handle devenv environments when using git submodules (e.g., .cursor/setup) to avoid "not tracked by Git" errors.

## Trigger
When running `devenv shell` or other devenv commands and seeing errors like:
```
error: Path '.cursor/nix/devenv.nix' in the repository "..."
is not tracked by Git.
```
This occurs because devenv (via Nix) expects all source files to be git-tracked, but submodule contents appear as untracked files.

## Steps
1. **Ensure the submodule is properly initialized**
   ```bash
   git submodule update --init --recursive <submodule-path>
   # Example: git submodule update --init --recursive .cursor
   ```
   Verify it is a gitlink: `git ls-files -s <submodule-path>` should show mode `160000`.

2. **Configure devenv to ignore untracked files in submodules**
   Add the following to your `devenv.yaml` (create if missing):
   ```yaml
   nixConfig:
     git-ignore-untracked = true
   ```
   This tells the Nix evaluator (used by devenv) to ignore untracked files, allowing submodule contents to be used without triggering the error.

3. **Verify the fix**
   Run a simple devenv command to ensure it works:
   ```bash
   devenv shell -- echo hello
   # Should succeed without the "not tracked by Git" error.
   ```

## Pitfalls
- **Submodule not initialized**: If you only run `git submodule update` without `--init`, the submodule may remain as a plain directory, causing the error to persist. Always use `--init` when cloning fresh or after removing the submodule directory.
- **Incorrect placement of `nixConfig`**: Ensure it is at the top level of `devenv.yaml`, not nested under `inputs` or other sections.
- **Forgetting to pull updates**: After changing `devenv.yaml`, pull the latest changes on all hosts and re‑run `git submodule update` to ensure consistency.
- **Confusing with Git's own ignore**: This setting only affects Nix/devenv evaluation; it does not change how Git tracks files. The submodule remains a gitlink and its internal files are managed by the submodule's own repository.

## Reference
See `references/error-transcript.md` for a real‑world example of the error and the fix applied.

## Related Skills
- `hermes-configuration-management` (for backing up/restoring Hermes config)
- `nixos-managing` (for broader NixOS system tasks)