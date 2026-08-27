# Error Transcript: devenv with .cursor submodule

## Error Message
```
error: Path '.cursor/nix/devenv.nix' in the repository "/home/tome/.dotfiles" is not tracked by Git.
```

## Context
- Occurred on host `huginn` when running devenv commands
- Same repository works fine on other hosts (`mimir` and current host)
- `.cursor` is a git submodule pointing to `https://github.com/Industrial/cursor-setup`
- Submodule was properly initialized (checked via `git submodule status .cursor`)
- Git itself did not report the file as untracked (`git ls-files --others` showed nothing)
- The error originated from devenv/Nix evaluation, not direct Git commands

## Root Cause
Devenv uses Nix to evaluate flakes, and Nix expects all source files to be visible to Git (i.e., tracked or properly ignored). When a submodule is present, its contents appear as untracked files to the parent repository's Git index, causing Nix to throw an error about untracked files in the source tree.

## Fix Applied
1. **Verified submodule initialization**:
   ```bash
   git submodule update --init --recursive .cursor
   ```
   Confirmed gitlink status: `git ls-files -s .cursor` shows `160000` mode.

2. **Added Nix configuration to ignore untracked files** in `devenv.yaml`:
   ```yaml
   nixConfig:
     git-ignore-untracked = true
   ```

3. **Verified the fix**:
   ```bash
   devenv shell echo hello
   # Now succeeds without error
   ```

## Files Changed
- `/home/tom/.dotfiles/devenv.yaml` - added `nixConfig.git-ignore-untracked = true`
- `/home/tom/.dotfiles/.cursor/nix/devenv.nix` - ensured submodule content is present (no direct changes needed to this file)

## Verification
After the fix, devenv commands work correctly on all hosts, including huginn. The submodule remains a proper gitlink and its contents are accessible to devenv/Nix without triggering the untracked file error.