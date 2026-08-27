#!/usr/bin/env bash
# Close the loop: refuse to end a turn on code that does not lint or compile.
#
# Every other hook here is restrictive — it denies a write, blocks a tool,
# confines a path. This one is the opposite, and it is the only one that makes a
# session verify its own work before declaring itself done. The guidance for
# unattended runs is "give Claude a check it can run"; a Stop hook is that check
# as a mechanism instead of a request.
#
# Deliberately NOT wired to `definitively run pre-commit`: those programs contain
# llm: nodes that spawn a nested Claude. A Stop hook that starts another agent to
# grade this one is an inception loop that costs a whole session per turn. The
# gate here is pure CLI — no model anywhere in the path — so the session that
# made the mess is the session that cleans it up, with the failure text already
# in its own context.
#
# Gate tiers (CLAUDE_STOP_GATE, default "lint,types"):
#   lint   bun run oxlint     ~0.2s   oxlint . --deny-warnings
#   types  bun run typecheck  ~11s    biome check + tsgo -b --noEmit
#   tests  moon run :test --affected --cache off   (opt in — slowest tier)
#
# Tests are off by default on purpose. A gate slow enough to be annoying gets
# turned off within a day, and lint+types already catches the dominant failure
# mode: "Claude said done" on code that does not compile. Tests stay where they
# were, on the pre-push gate.
#
# Fails OPEN on infrastructure problems (no bun, no git, not a repo) — a gate
# that cannot run must never trap the agent. Fails CLOSED on real gate failures.
#
# Wire protocol: exit 2 blocks the turn and feeds stderr back to Claude; exit 0
# lets the turn end.
#
# Escape hatch: CLAUDE_SKIP_STOP_GATE=1. Prefer fixing the failure.
set -uo pipefail

input="$(cat 2>/dev/null || true)"
[ -n "$input" ] || input='{}'

[ "${CLAUDE_SKIP_STOP_GATE:-0}" = "1" ] && exit 0

# Loop guard 1: Claude Code sets stop_hook_active when it is already continuing
# because a Stop hook blocked. Never block off the back of our own block.
if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
    exit 0
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$repo" 2>/dev/null || exit 0

# Infrastructure checks — every one of these fails open.
command -v git >/dev/null 2>&1 || exit 0
command -v jq  >/dev/null 2>&1 || exit 0
command -v bun >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Recon modes produce no code, so there is nothing to verify. EXECUTE, SHIP and
# a disengaged ID session all gate normally.
state="$repo/.tmp/id/state.json"
if [ -f "$state" ]; then
    case "$(jq -r '.mode // ""' "$state" 2>/dev/null || true)" in
        ORIENT|RESEARCH|PLAN|REVIEW) exit 0 ;;
    esac
fi

# What changed. Renames report "old -> new"; keep the new path. .cursor is a
# submodule and .tmp/.maestro are harness state, none of which the gate covers.
changed="$(git status --porcelain --untracked-files=all 2>/dev/null \
    | cut -c4- \
    | sed 's/.* -> //' \
    | grep -Ev '^\.(tmp|maestro|cursor)(/|$)' \
    | grep -E '\.(ts|tsx|mts|cts|js|jsx)$' \
    || true)"
[ -n "$changed" ] || exit 0

# Fingerprint exactly what the gate judges: the list of changed source files and
# the content of each. Deliberately not `git diff HEAD` — a cold `tsgo -b` writes
# build state, which moved the whole-tree diff between two otherwise identical
# runs and cost a redundant gate pass. Hashing only the files under judgement is
# both cheaper and immune to unrelated churn.
fingerprint="$( {
    printf '%s\n' "$changed"
    printf '%s\n' "$changed" | while IFS= read -r f; do
        [ -f "$f" ] && git hash-object "$f" 2>/dev/null
    done
} | sha256sum 2>/dev/null | cut -d' ' -f1)"
[ -n "$fingerprint" ] || exit 0

# CLAUDE_STOP_GATE_DEBUG=1 traces why a run did or did not hit the cache.
[ "${CLAUDE_STOP_GATE_DEBUG:-0}" = "1" ] && \
    printf 'stop-gate: fp=%.16s files=%s\n' "$fingerprint" \
    "$(printf '%s\n' "$changed" | tr '\n' ',')" >&2

gate_dir="$repo/.tmp/stop-gate"
mkdir -p "$gate_dir" 2>/dev/null || exit 0
pass_file="$gate_dir/last-pass"
fail_file="$gate_dir/last-fail"

# Already verified green for exactly this tree — do not re-run on every turn.
[ "$(cat "$pass_file" 2>/dev/null || true)" = "$fingerprint" ] && exit 0

# Loop guard 2: three blocks on an unchanged tree means the session is stuck in
# a way another block will not fix. Hand control back to the human. Claude Code
# gives up at 8; stopping at 3 wastes five fewer turns.
prev_fail="$(cut -d' ' -f1 "$fail_file" 2>/dev/null || true)"
fail_count="$(cut -d' ' -f2 "$fail_file" 2>/dev/null || true)"
[ -n "${fail_count:-}" ] || fail_count=0
if [ "$prev_fail" = "$fingerprint" ] && [ "$fail_count" -ge 3 ] 2>/dev/null; then
    exit 0
fi

gates="${CLAUDE_STOP_GATE:-lint,types}"
gate_enabled() { case ",$gates," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

# A bun-script gate only makes sense where the repo defines that script. This
# plugin is vendored into repos whose stack has no package.json scripts at all
# (Rust/Python), where `bun run oxlint` fails as "Script not found" on every
# turn regardless of the diff. Skip the tier rather than report a false failure.
has_script() {
[ -f package.json ] || return 1
jq -e --arg s "$1" '.scripts[$s] // empty' package.json >/dev/null 2>&1
}

failed_gate=""
failed_cmd=""
report=""

if [ -z "$failed_gate" ] && gate_enabled lint && has_script oxlint; then
if ! report="$(bun run oxlint 2>&1)"; then
    failed_gate="lint"; failed_cmd="bun run oxlint"
fi
fi

if [ -z "$failed_gate" ] && gate_enabled types && has_script typecheck; then
if ! report="$(bun run typecheck 2>&1)"; then
    failed_gate="types"; failed_cmd="bun run typecheck"
fi
fi

if [ -z "$failed_gate" ] && gate_enabled tests; then
if command -v moon >/dev/null 2>&1; then
    if ! report="$(moon run :test --affected --cache off 2>&1)"; then
        failed_gate="tests"; failed_cmd="moon run :test --affected --cache off"
    fi
fi
fi

if [ -z "$failed_gate" ]; then
printf '%s' "$fingerprint" > "$pass_file"
rm -f "$fail_file"
exit 0
fi

if [ "$prev_fail" = "$fingerprint" ]; then
fail_count=$((fail_count + 1))
else
fail_count=1
fi
printf '%s %s' "$fingerprint" "$fail_count" > "$fail_file"
rm -f "$pass_file"

# Bound what goes back into context. The tail carries the actual errors; the
# head of a lint/tsc run is almost always banner noise.
{
printf 'STOP GATE FAILED — %s (attempt %s of 3)\n\n' "$failed_gate" "$fail_count"
printf '%s\n' "$report" | tail -n 60
printf '\n---\n'
printf 'The turn is blocked: %s files changed and `%s` does not pass.\n' \
"$(printf '%s\n' "$changed" | wc -l | tr -d ' ')" "$failed_cmd"
    printf 'Fix the failures above, then finish. Do not weaken the gate to get past it.\n'
} >&2

exit 2
