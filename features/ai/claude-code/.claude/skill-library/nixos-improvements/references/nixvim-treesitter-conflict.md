# Nixvim Treesitter Version Conflict — Debugging Transcript

## Error
```
error: You cannot include two different versions of nvim-treesitter, perhaps you included a legacy plugin together with a new one?
```

## Context
The nixvim feature at `features/programming/neovim/language-support.nix` configured three treesitter-related plugins/modules:
- `treesitter` (new main-branch module) — OK
- `treesitter-context` (separate package) — OK
- `treesitter-refactor` (legacy consumer) — **CAUSES CONFLICT**

## Root Cause
`treesitter-refactor` bundles its own copy of the legacy `nvim-treesitter` (master branch) package, which conflicts with the new `treesitter` module (main branch). The new nixvim `treesitter` module targets the nvim-treesitter **main** branch and uses Neovim's native treesitter APIs. Legacy plugins that call `require('nvim-treesitter.configs').setup()` pull in the old package, creating a version conflict during evaluation.

## Reproduction
```bash
# After uncommenting neovim in profiles/development.nix:
NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure
# → error: You cannot include two different versions of nvim-treesitter
```

## Fix
Remove `treesitter-refactor` from `language-support.nix`:
```nix
# Before:
treesitter-refactor = {
  enable = true;
};

# After: removed entirely, with explanatory comment
```

## Stash-and-compare verification technique
```bash
# 1. Stash changes
git stash

# 2. Run flake check on original — note baseline errors
NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure 2>&1 | grep "error:"

# 3. Pop changes
git stash pop

# 4. Run flake check again — compare
NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure 2>&1 | grep "error:"
```

Before fix: `error: You cannot include two different versions of nvim-treesitter`
After fix: `error: sphinx-9.1.0 not supported for interpreter python3.11` (separate pre-existing issue)

## Upstream
- GitHub Issue: https://github.com/nix-community/nixvim/issues/4188
- nixvim docs: https://nix-community.github.io/nixvim/plugins/treesitter/index.html
- nixvim FAQ: https://nix-community.github.io/nixvim/user-guide/faq.html