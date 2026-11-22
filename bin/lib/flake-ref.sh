#!/usr/bin/env bash
# git_flake_ref <dir>: the flake reference for <dir>'s git-tracked source, on stdout.
#
# Give `builtins.getFlake` this, never a bare directory (#266). getFlake on a plain path
# string, like `nix eval path:<dir>`, copies the WHOLE directory into the world-readable
# store: .git, .tmp, target/, .devenv and every ignored file (25-34 GB for the main
# checkout). A git+file reference copies only the tracked files, uncommitted edits to them
# included, and that holds in a git worktree (where .git is a file) as well.
# (Nix's command line already does this for `.#…` and bare directories; getFlake does not.)
#
# shallow=1 so a shallow CI checkout evaluates too; it costs nothing on a full clone.
# A flake below the repository's top level gets `&dir=<relative path>`. Fails, rather
# than falling back to a path, when <dir> is not inside a git work tree.
git_flake_ref() {
    local dir top rel
    dir="$(cd "$1" 2>/dev/null && pwd -P)" || {
        echo "git_flake_ref: no such directory: $1" >&2
        return 1
    }
    top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || {
        echo "git_flake_ref: $dir is not in a git work tree; refusing to hand Nix a whole-directory copy (#266)" >&2
        return 1
    }
    top="$(cd "$top" && pwd -P)"
    rel="${dir#"$top"}"
    rel="${rel#/}"
    if [ -n "$rel" ]; then
        printf 'git+file://%s?shallow=1&dir=%s\n' "$top" "$rel"
    else
        printf 'git+file://%s?shallow=1\n' "$top"
    fi
}
