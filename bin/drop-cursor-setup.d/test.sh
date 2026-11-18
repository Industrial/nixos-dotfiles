#!/usr/bin/env bash
# Regression tests for bin/drop-cursor-setup's safety behaviour.
#
#   bin/drop-cursor-setup.d/test.sh
#
# Uses throwaway clones of ~/.dotfiles under .tmp/drop-cursor-setup/test-*.
# Covers what must never regress: report mode changes nothing; foreign edits
# to a file the tool rewrites stop it (exit 3); the host-wide harness
# .claude-setup is never removed (exit 2); a migrated repo is a no-op. The
# full --apply path is exercised on a scratch clone (see the mission evidence),
# because it needs a real devenv evaluation and takes minutes.
set -uo pipefail
DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOL="$DOT/bin/drop-cursor-setup"
T="$DOT/.tmp/drop-cursor-setup"
pass=0 fail=0
check() { # check <name> <expected-exit> <cmd...>
    local name=$1 want=$2; shift 2
    "$@" > "$T/test.out" 2>&1; local got=$?
    if [ "$got" = "$want" ]; then pass=$((pass + 1)); echo "PASS $name"
else fail=$((fail + 1)); echo "FAIL $name (exit $got, want $want)"; tail -n 5 "$T/test.out" | sed 's/^/    /'; fi
}
fresh() { # fresh <dir>: clone ~/.dotfiles at its last pre-migration commit, .cursor checked out
    rm -rf "$1"
    git clone -q --no-local "$DOT" "$1" && git -C "$1" checkout -q 6d7d1c4f &&
    git -C "$1" submodule update -q --init .cursor
}
mkdir -p "$T"

R="$T/test-report"
fresh "$R"
before="$(git -C "$R" status --porcelain)"
check "report mode exits 0 (with --keep-claude-setup)" 0 "$TOOL" "$R" --keep-claude-setup
after="$(git -C "$R" status --porcelain)"
if [ "$before" = "$after" ]; then pass=$((pass + 1)); echo "PASS report mode leaves the tree unchanged"
else fail=$((fail + 1)); echo "FAIL report mode changed the tree"; fi

echo "# foreign edit" >> "$R/devenv.nix"
check "foreign edit in devenv.nix stops --apply (exit 3)" 3 "$TOOL" "$R" --apply --keep-claude-setup
if git -C "$R" diff --quiet HEAD -- . ':!devenv.nix' && [ -z "$(git -C "$R" ls-files --others --exclude-standard -- nix)" ]; then
    pass=$((pass + 1)); echo "PASS refusal touched nothing else"
else fail=$((fail + 1)); echo "FAIL refusal left changes behind"; fi
git -C "$R" checkout -q -- devenv.nix

# ~/.dotfiles' own .claude-setup is the host-wide harness: removal must be refused.
check "host-wide harness .claude-setup is protected (exit 2)" 2 "$TOOL" "$DOT"

check "usage error without a repo (exit 2)" 2 "$TOOL"
check "unknown flag (exit 2)" 2 "$TOOL" "$R" --frobnicate

# A repo without any .cursor setup is already migrated.
E="$T/test-empty"
rm -rf "$E"; mkdir -p "$E" && git -C "$E" init -q && git -C "$E" commit -q --allow-empty -m init
check "repo without .cursor is a no-op" 0 "$TOOL" "$E" --apply
grep -q "already migrated" "$T/test.out" && { pass=$((pass + 1)); echo "PASS no-op says 'already migrated'"; } || { fail=$((fail + 1)); echo "FAIL no-op message"; }

rm -rf "$R" "$E"

# FULL=1: a stale foreign edit is carried through a real --apply (minutes: devenv eval)
if [ "${FULL:-0}" = 1 ]; then
    C="$T/test-carry"
    fresh "$C"
    printf '\n# foreign stale edit (carry test)\n' >> "$C/devenv.nix"
    touch -d '5 days ago' "$C/devenv.nix"
    check "stale foreign edit is carried through --apply" 0 "$TOOL" "$C" --apply --keep-claude-setup
    if git -C "$C" log -p 6d7d1c4f..HEAD -- devenv.nix | grep -q 'carry test'; then
        fail=$((fail + 1)); echo "FAIL the carried edit leaked into a commit"
else pass=$((pass + 1)); echo "PASS no commit contains the carried edit"; fi
    if tail -n 2 "$C/devenv.nix" | grep -q 'carry test' && git -C "$C" diff --name-only | grep -qx devenv.nix &&
    ! git -C "$C" diff --cached --name-only | grep -qx devenv.nix; then
        pass=$((pass + 1)); echo "PASS the edit is back, unstaged, on top of the migrated file"
else fail=$((fail + 1)); echo "FAIL the carried edit was not restored as an unstaged change"; fi
    if git -C "$C" show HEAD:devenv.nix | grep -q 'local.features'; then
        pass=$((pass + 1)); echo "PASS the committed devenv.nix is migrated"
else fail=$((fail + 1)); echo "FAIL committed devenv.nix not migrated"; fi
    rm -rf "$C"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
