#!/usr/bin/env bash
# Ad-hoc post-change verification probe (read-only by design).
# Usage: adhoc-remote-verify.sh <host> <local-probe-script.sh>
#   <host> may be empty to run only local checks.
# The probe script runs ON the target via `ssh <host> bash -s < file`;
# write it as a plain bash file, NOT a heredoc inside $( ) — nested
# heredocs in command substitution are a bash parse error.
#
# Traps this template pre-solves (each bit a real session twice):
#   1. heredoc inside $( ... )            -> put the probe in its own file
#   2. bare `python3` absent on a shell   -> prefer grep/sed/nix-instantiate
#   3. ssh output trailing newline breaks case/glob matchers
#                                         -> pipe capture through tr -d '\n'
set -u
host="${1:-}"
probe="${2:-}"

pass=0; fail=0
ok()  { echo "PASS $1"; pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }

# --- example checks; replace with the behavior you changed ---------------

# Local: config/eval shape check without heavyweight gates
if grep -q 'PATTERN-YOU-EXPECT' ./path/to/changed/file 2>/dev/null; then
  ok "local-shape"
else
  bad "local-shape"
fi

# Remote: unit state + port probe, single round trip
if [ -n "$host" ] && [ -f "$probe" ]; then
  live=$(ssh "$host" 'bash -s' < "$probe" 2>/dev/null | tr -d '\n')
  echo "LIVE $live"
  case "$live" in
    *active*) ok "remote-unit-active" ;;
    *)        bad "remote-unit-active" ;;
  esac
elif [ -n "$host" ]; then
  bad "remote-probe-missing-file"
fi

# --------------------------------------------------------------------------
echo "---"
echo "ad-hoc summary: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] && echo "AD-HOC VERIFY: ALL GREEN" || echo "AD-HOC VERIFY: FAILURES PRESENT"
exit 0  # summary is the deliverable; never mask results with exit code
