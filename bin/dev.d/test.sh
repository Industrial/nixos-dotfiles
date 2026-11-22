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
lacks "check builds or evaluates no host by default" '^  (check-|flake-checks|cargo-|shell-budget|clamav|lynis|stig) '
has "check format-checks only changed files by default" '^  format +bin/dev format --check$'
expect "check --format-all checks the whole tree, as CI" 0 '^  format +bin/dev format --check --all$' "$DEV" check -n --no-rust --format-all
expect "check --host runs CI's check-host for it" 0 '^  check-mimir +bin/ci/check-host mimir$' "$DEV" check -n --no-rust --host mimir
# --hosts takes the host list from the flake, like ci.yml's generated matrix;
# BIN_DEV_HOSTS stands in for `nix eval .#nixosConfigurations` here.
expect "check --hosts covers every nixosConfigurations host" 0 '^  check-installer ' \
    env BIN_DEV_HOSTS="drakkar huginn installer mimir muninn" "$DEV" check -n --no-rust --hosts
for h in drakkar huginn mimir muninn; do has "check --hosts has $h" "^  check-$h "; done
expect "check --rust adds the cargo jobs" 0 '^  cargo-clippy ' "$DEV" check -n --rust
has "check --rust has cargo-test" '^  cargo-test '
has "check --rust has cargo-nix-drift" '^  cargo-nix-drift '
has "check --rust has cargo-standalone, every standalone crate" '^  cargo-standalone +bin/ci/cargo-standalone all$'
expect "check --flake-checks runs bin/ci/flake-checks" 0 '^  flake-checks +bin/ci/flake-checks$' "$DEV" check -n --no-rust --flake-checks
expect "check --scans adds clamav, lynis, stig" 0 '^  stig +bin/ci/stig$' "$DEV" check -n --no-rust --scans
expect "check --shell-budget adds it" 0 '^  shell-budget +bin/ci/shell-budget$' "$DEV" check -n --no-rust --shell-budget

# --all is ci.yml's job list: every job there (bar the `hosts` and
# `standalone-crates` listers and the `all-green` gate) is a step here, and every
# step here is a job there.
ci_jobs="$(sed -n '/^jobs:/,$p' "$DOT/.github/workflows/ci.yml" | grep -oE '^  [a-z][a-z0-9-]*:' | tr -d ' :' | grep -vxE 'hosts|standalone-crates|all-green' | sort)"
expect "check --all prints the whole plan" 0 '^  check-mimir ' \
    env BIN_DEV_HOSTS="mimir" "$DEV" check -n --all
plan_jobs="$(grep -oE '^  [a-z][a-z0-9-]* ' "$T/out" | tr -d ' ' | sed 's/^check-.*/check/' | sort -u)"
if [ -n "$ci_jobs" ] && [ "$ci_jobs" = "$plan_jobs" ]; then
    ok "check --all matches ci.yml's jobs ($(wc -l <<<"$ci_jobs"))"
else
    ko "check --all differs from ci.yml's jobs"
    diff <(echo "$ci_jobs") <(echo "$plan_jobs") | sed 's/^/    /'
fi
expect "check --only narrows the plan" 0 '^  deadnix ' "$DEV" check -n --no-rust --only deadnix
lacks "check --only drops the rest" '^  format '
expect "check --skip drops a step" 0 '^  format ' "$DEV" check -n --no-rust --skip deadnix
lacks "check --skip dropped deadnix" '^  deadnix '
expect "pre-push is check" 0 '^  lint-fetch-pins ' "$DEV" pre-push -n --no-rust
expect "check rejects a bad host name" 64 'not a host name' "$DEV" check -n --host 'x;y'
expect "check rejects an unknown option" 64 "unknown option '--bogus'" "$DEV" check --bogus
expect "check --only with no match is an error" 64 'left no steps' "$DEV" check -n --only nope

# --- bin/ci/cargo-standalone --list (the cargo-standalone matrix) -------------
# A fixture rust/ tree: a workspace member, two standalone crates, and later an
# orphan that neither job would check.
CS="$DOT/bin/ci/cargo-standalone"
crate() { # crate <dir> <with [workspace]: 0|1>
    mkdir -p "$1"
    printf '[package]\nname = "%s"\nversion = "0.1.0"\n' "$(basename "$1")" >"$1/Cargo.toml"
    if [ "$2" = 1 ]; then printf '\n[workspace]\n' >>"$1/Cargo.toml"; fi
}
mkdir -p "$T/rust"
printf '[workspace]\nmembers = ["tools/member"]\n' >"$T/rust/Cargo.toml"
crate "$T/rust/tools/member" 0
crate "$T/rust/tools/alpha" 1
crate "$T/rust/tools/beta" 1
expect "cargo-standalone --list finds the standalone crates, sorted" 0 '^\["alpha", "beta"\]$' \
    env RUST_DIR="$T/rust" "$CS" --list
lacks "cargo-standalone --list leaves out workspace members" 'member'
crate "$T/rust/tools/orphan" 0
expect "cargo-standalone --list fails on a crate no job checks" 1 'orphan: neither a member' \
    env RUST_DIR="$T/rust" "$CS" --list
rm -rf "$T/rust/tools/orphan" "$T/rust/tools/alpha" "$T/rust/tools/beta"
expect "cargo-standalone --list fails when it finds nothing" 1 'no standalone crate' \
    env RUST_DIR="$T/rust" "$CS" --list
expect "cargo-standalone --list on this tree has nixos-update-notifier and vcache" 0 '"vcache"' "$CS" --list
has "and nixos-update-notifier" '"nixos-update-notifier"'
lacks "and not the workspace member oomkiller" 'oomkiller'
expect "cargo-standalone rejects a bad crate name" 1 "not a crate name" "$CS" clippy 'x;y'
expect "cargo-standalone rejects a crate it did not find" 1 "not a standalone crate" "$CS" test oomkiller
expect "cargo-standalone package rejects a bad crate name" 1 "not a crate name" "$CS" package 'x;y'
expect "cargo-standalone package rejects a bad host name" 1 "not a host name: 'x;y'" \
    env CARGO_STANDALONE_HOST='x;y' "$CS" package vcache
expect "cargo-standalone usage lists package" 64 'package <crate> +nix build its default.nix' "$CS"

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

# --- the build monitor (GH-181) ----------------------------------------------
# vmon replaced nom: bin/dev builds through it (nom only where a host rolled vmon
# back), and bin/update/system and bin/fleet build the closure through it first.
expect "bin/dev build prefers vmon" 0 '^    builder=\(vmon -- nix\)$' cat "$DEV"
has "and falls back to nom after it" '^  elif command -v nom >/dev/null 2>&1; then$'
expect "bin/update/system builds the closure through vmon" 0 '^  vmon -- nix build --no-link "\$toplevel"$' \
    cat "$DOT/bin/update/system"
# vswitch took over the local switch (GH-241): bin/update/system switches through it, and
# only a host without it (the rollback) reaches nixos-rebuild.
expect "bin/update/system switches through vswitch" 0 '^  switch="vswitch switch --flake ' \
    cat "$DOT/bin/update/system"
has "and nixos-rebuild only without it" '^if \[ -z "\$.vswitched:-." \]; then$'
expect "bin/fleet builds each node's profile through vmon" 0 '^  vmon -- nix build --no-link ".#deploy.nodes.\$1.profiles.system.path"$' \
    cat "$DOT/bin/fleet"
has "and before every deploy" '^        if ! prebuild "\$h" \|\| ! deploy_cmd'

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
