# Handling Divergent Branches After Rebasing

## Scenario
You have rebased your feature branch onto main, but when you try to push, you get a "non-fast-forward" error because the remote branch has diverged from your local branch.

## Example from Session
```
To github.com:Industrial/nixos-dotfiles.git
 ! [rejected]          secure-boot-implementation -> secure-boot-implementation (non-fast-forward)
error: failed to push some refs to 'github.com:Industrial/nixos-dotfiles.git'
hint: Updates were rejected because the tip of your current branch is behind
hint: its remote counterpart. If you want to integrate the remote changes,
hint: use 'git pull' before pushing again.
```

## Solution Steps
1. **Do NOT use regular `git pull`** - this creates a merge commit
2. **Use `git pull --rebase`** instead to maintain linear history:
   ```bash
   git pull --rebase origin <branch-name>
   ```
3. **Verify the result** - your branch should now be ready to push
4. **Push normally**:
   ```bash
   git push origin <branch-name>
   ```

## Why This Approach
- Preserves the clean, linear history from your rebase
- Avoids unnecessary merge commits in the branch history
- Is the recommended approach for preparing branches for release
- Aligns with ID SHIP mode principles of clean git operations

## Verification
After executing these steps:
- `git status` should show "Your branch is up to date with 'origin/<branch-name>.'"
- `git log --oneline --graph origin/<branch-name>..HEAD` should show only your local commits
- `git push` should succeed without errors