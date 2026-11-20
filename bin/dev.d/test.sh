#!/usr/bin/env bash
# Regression tests for bin/dev and bin/with-devenv: the help listing, argument
# errors, the check plan, and the messages a script gives outside devenv.
#
#   bin/dev.d/test.sh
#
# Fast (no evaluation, no network) so bin/dev check runs it every time.
set -uo pipefail
DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEV="$DOT/bin/dev"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0 fail=0

ok() {
    pass=$((pass + 1))
    echo "PASS $*"
}
ko() {
    fail=$((fail + 1))
    echo "FAIL $*"
}

# expect <name> <want-exit> <pattern|-> <cmd...>: the exit code and, unless the
# pattern is '-', a line of combined output matching the extended regex.
expect() {
    local name=$1 want=$2 pat=$3
    shift 3
    "$@" >"$T/out" 2>&1
    local got=$?
    if [ "$got" != "$want" ]; then
        ko "$name (exit $got, want $want)"
        sed 's/^/    /' "$T/out" | tail -n 8
    elif [ "$pat" != - ] && ! grep -qE -- "$pat" "$T/out"; then
        ko "$name (no line matching /$pat/)"
        sed 's/^/    /' "$T/out" | tail -n 8
    else
        ok "$name"
    fi
}
# has <name> <pattern>: the previous command's output has such a line.
has() { if grep -qE -- "$2" "$T/out"; then ok "$1"; else ko "$1 (no /$2/)"; fi; }
# lacks <name> <pattern>: the previous command's output has no such line.
lacks() { if grep -qE -- "$2" "$T/out"; then ko "$1 (unexpected /$2/)"; else ok "$1"; fi; }

# A PATH holding only what bin/dev and bin/with-devenv need for themselves, so
# every toolchain command (nix, devenv and the devenv packages) is absent.
mkdir -p "$T/bare"
for c in bash dirname cat; do
    ln -s "$(command -v "$c")" "$T/bare/$c"
done
bare() { env -i PATH="$T/bare" HOME="$T" "$@"; }

# --- the listing -------------------------------------------------------------
expect "no arguments prints the command list" 0 '^Before pushing' "$DEV"
for c in check pre-push test format lint eval hosts build deploy update repl doctor; do
    has "help lists '$c'" "^  $c( |$)"
done
expect "help is the same listing" 0 '^Everyday' "$DEV" help
expect "unknown command exits 64 and says so" 64 "unknown command 'frobnicate'" "$DEV" frobnicate

# --- the check plan ----------------------------------------------------------
expect "check -n prints the plan" 0 '^bin/dev check' "$DEV" check -n --no-rust
for s in format deadnix feature-reachability lint-fetch-pins assay bin-dev-selftest; do
    has "check plan has $s" "^  $s "
done
lacks "check builds or evaluates no host by default" '^  (eval-|flake-check|cargo-)'
has "check format-checks only changed files by default" '^  format +bin/dev format --check$'
expect "check --format-all checks the whole tree, as CI" 0 '^  format +bin/dev format --check --all$' "$DEV" check -n --no-rust --format-all
expect "check --host adds that host's eval" 0 '^  eval-mimir +bin/dev eval mimir' "$DEV" check -n --no-rust --host mimir
expect "check --hosts covers the CI matrix" 0 '^  eval-huginn ' "$DEV" check -n --no-rust --hosts
has "check --hosts has drakkar" '^  eval-drakkar '
has "check --hosts has mimir" '^  eval-mimir '
expect "check --rust adds the cargo jobs" 0 '^  cargo-clippy ' "$DEV" check -n --rust
has "check --rust has cargo-test" '^  cargo-test '
expect "check --flake-check adds nix flake check" 0 '^  flake-check +nix flake check --no-build' "$DEV" check -n --no-rust --flake-check
expect "check --only narrows the plan" 0 '^  deadnix ' "$DEV" check -n --no-rust --only deadnix
lacks "check --only drops the rest" '^  format '
expect "check --skip drops a step" 0 '^  format ' "$DEV" check -n --no-rust --skip deadnix
lacks "check --skip dropped deadnix" '^  deadnix '
expect "pre-push is check" 0 '^  lint-fetch-pins ' "$DEV" pre-push -n --no-rust
expect "check rejects a bad host name" 64 'not a host name' "$DEV" check -n --host 'x;y'
expect "check rejects an unknown option" 64 "unknown option '--bogus'" "$DEV" check --bogus
expect "check --only with no match is an error" 64 'left no steps' "$DEV" check -n --only nope

# --- argument errors ---------------------------------------------------------
expect "test with an unknown feature exits 64" 64 "no path or feature named 'no-such-feature'" "$DEV" test no-such-feature
expect "update lists its targets" 0 '^  flake$' "$DEV" update
expect "update rejects an unknown target" 64 "unknown target 'nope'" "$DEV" update nope
expect "build needs a host" 64 'exactly one host' "$DEV" build
expect "format only knows --check" 64 "unknown option '--write'" "$DEV" format --write
expect "eval takes one host" 64 'eval takes one host' "$DEV" eval a b

# --- outside devenv ----------------------------------------------------------
# BIN_DEV_REEXEC=1 marks the re-exec as spent: the state after bin/with-devenv
# already ran and the tool is still missing.
expect "a feature name resolves, then the missing tool is named" 127 'missing on PATH: assay' \
    bare BIN_DEV_REEXEC=1 bash "$DEV" test nushell
has "and it says how to get it" 'Re-enter the shell once'
expect "with no devenv at all, it points at bin/with-devenv" 127 'bin/with-devenv bin/dev format' \
    bare bash "$DEV" format
has "and at the prerequisites" 'docs/development.md#prerequisites'
expect "a host tool is reported as a host tool" 127 "'nix' comes from the host" \
    bare BIN_DEV_REEXEC=1 bash "$DEV" eval mimir

# bin/with-devenv in a checkout with no .devenv link and no devenv installed.
mkdir -p "$T/repo/bin"
cp "$DOT/bin/with-devenv" "$T/repo/bin/with-devenv"
expect "with-devenv without devenv explains instead of 'command not found'" 127 \
    'cannot supply the devenv toolchain for .frob.' \
    bare bash "$T/repo/bin/with-devenv" frob --x
expect "with-devenv with no command prints usage" 64 '^usage: bin/with-devenv' \
    bare bash "$T/repo/bin/with-devenv"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
