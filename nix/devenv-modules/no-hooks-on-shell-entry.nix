# Entering the devenv shell must not run the git hooks.
#
# Vendored by bin/drop-cursor-setup from ~/.dotfiles. devenv's git-hooks
# integration declares `devenv:git-hooks:run` (`prek run -a`) as
# `before devenv:enterTest`, and devenv runs `devenv:enterShell` in
# `--mode all`, which also pulls in enterShell's dependents: enterTest, and
# through it the hook run. So every `devenv shell`, interactive or
# `-- <cmd>`, ran every hook across the repo, and prek's tree-wide stash ran
# with it, under every concurrent session. Hooks belong to git (commit, push).
# `devenv test` no longer runs them either; `prek run -a` does that on demand.
{lib, ...}: {
  tasks."devenv:git-hooks:run".before = lib.mkForce [];
}
