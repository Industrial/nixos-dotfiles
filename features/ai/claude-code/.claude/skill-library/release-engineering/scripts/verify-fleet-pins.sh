#!/usr/bin/env bash
# verify-fleet-pins.sh — ad-hoc fleet rollout verifier for the Assay project.
# Re-run after every rollout: parameterize V / SRI / REV at the top.
# Checks: consumer pin files, SRI truth vs cached release tarball,
# dotfiles lockfile revs + scope, functional suite spot-runs via the release tag.
#
# Usage: bash verify-fleet-pins.sh ; exit code 0 = all green.
set -u
V="0.2.1"                                          # <-- bump per release
SRI="sha256-zaejB1zfDQ214UJizIq9ds33BLpD7SrwL+USZaR9LvY="  # <-- nix hash file --sri --type sha256 <tarball>
REV="ec53f593b967093433d96bf0c90708b9250bf865"     # <-- release commit (git rev-parse vX.Y.Z)
TARBALL="/tmp/assay-v${V}.tar.gz"                  # pre-download: curl -sL <release-url> -o $TARBALL

FILES=(
  /data/Code/rust/test-loco-webapp/.cursor/nix/features/program-assay.nix
  /data/Code/rust/solana-yield-optimizer/.cursor/nix/features/program-assay.nix
  /data/Code/idclear/monorepo/.cursor/nix/features/program-assay.nix
)
fail=0
chk() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $label"; else echo "FAIL  $label"; fail=1; fi; }

echo "== consumer pins =="
for f in "${FILES[@]}"; do
  repo=$(basename "$(dirname "$(dirname "$(dirname "$(dirname "$f")")")")")
  chk "$repo: version $V" grep -q "default = \"$V\"" "$f"
  chk "$repo: current SRI present" grep -qF "$SRI" "$f"
done

echo "== SRI truth vs release artifact =="
chk "tarball cached at $TARBALL" test -s "$TARBALL"
chk "SRI matches actual tarball bytes" \
  bash -c "[ \"\$(nix hash file --sri --type sha256 $TARBALL 2>/dev/null || nix hash-file --sri --type sha256 $TARBALL 2>/dev/null)\" = '$SRI' ]"

echo "== dotfiles locks =="
chk "flake.lock assay at ${REV:0:7}" bash -c "grep -A9 '\"assay\": {' ~/.dotfiles/flake.lock | grep -q '$REV'"
chk "devenv.lock assay at ${REV:0:7}" bash -c "grep -A9 '\"assay\": {' ~/.dotfiles/devenv.lock | grep -q '$REV'"
chk "devenv.lock diff is exactly one rev-line pair (no collateral input drift)" \
  bash -c "cd ~/.dotfiles && [ \"\$(git diff HEAD -- devenv.lock | grep -cE '^[-+].*\\\"rev\\\"')\" = 2 ]"

echo "== functional (release binary via nix run tag) =="
chk "test-loco-webapp 117/117" \
  bash -c "cd /data/Code/rust/test-loco-webapp && nix run github:Industrial/assay/v${V} -- run .cursor/nix 2>&1 | tail -1 | grep -q '117/117 passed'"
chk "idclear/monorepo 138/138" \
  bash -c "cd /data/Code/idclear/monorepo && nix run github:Industrial/assay/v${V} -- run .cursor/nix 2>&1 | tail -1 | grep -q '138/138 passed'"

echo
[ "$fail" -eq 0 ] && echo "RESULT: ALL CHECKS PASSED" || echo "RESULT: FAILURES PRESENT"
exit "$fail"
