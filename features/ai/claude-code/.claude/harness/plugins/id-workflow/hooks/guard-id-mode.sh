#!/usr/bin/env bash
# Enforce ID Workflow PROTOCOL rail 2 — "no code/config edits outside
# EXECUTE/SHIP" — as a mechanism instead of a promise.
#
# In Cursor the write ban is prose the agent agrees to follow. Here the mode in
# .tmp/id/state.json decides which paths a write tool may touch:
#
#   ORIENT   | RESEARCH  -> .tmp/** only            (recon modes write nothing)
#   PLAN                 -> + .maestro/**, .cursor/plans/**, specs
#   REVIEW               -> + .maestro/**           (evidence, not feature code)
#   EXECUTE  | SHIP      -> everything in-tree
#
# No state file means ID is disengaged -> allow everything. A session that never
# types /id is unaffected by this hook.
#
# Pairs with guard-write-paths.sh, which independently confines writes to the
# repo. This hook only decides WHICH in-tree paths the current mode may touch;
# out-of-tree paths are the other hook's business.
#
# Scope limit worth knowing: this guards file-write TOOLS. Shell-driven writes
# through ctx_shell are not intercepted (guarding shell command strings was
# deliberately out of scope), so the ban is strong against ordinary editing and
# porous against a determined `sed -i`.
#
# Wire protocol: PreToolUse deny JSON on stdout, or exit 0 to allow.
#
# Escape hatch: CLAUDE_ALLOW_ID_WRITES=1. Prefer advancing the mode.
set -euo pipefail

input="$(cat)"

if [ "${CLAUDE_ALLOW_ID_WRITES:-0}" = "1" ]; then
    exit 0
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
repo="$(realpath -m "$repo")"
state="$repo/.tmp/id/state.json"

[ -f "$state" ] || exit 0

mode="$(jq -r '.mode // ""' "$state" 2>/dev/null || true)"
lane="$(jq -r '.lane // ""' "$state" 2>/dev/null || true)"
[ -n "$mode" ] || exit 0

case "$mode" in
    EXECUTE|SHIP) exit 0 ;;
esac

# Prefix allowlist per mode. .tmp/ is always writable: it is the scratch and
# state area, and the mode marker itself lives there.
case "$mode" in
    ORIENT|RESEARCH) allowed=(".tmp/") ;;
    PLAN)            allowed=(".tmp/" ".maestro/" ".cursor/plans/") ;;
    REVIEW)          allowed=(".tmp/" ".maestro/") ;;
    *)               exit 0 ;;
esac

deny() {
    jq -nc --arg reason "$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
}

hook_cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

targets="$(printf '%s' "$input" | jq -r '
    (.tool_input // {})
    | [ .file_path?, .path?, .notebook_path?, (.paths[]?), (.ops[]?.path?) ]
    | map(select(type == "string" and length > 0))
    | .[]
')"

[ -n "$targets" ] || exit 0

while IFS= read -r target || [ -n "$target" ]; do
    [ -n "$target" ] || continue

    case "$target" in
        /*) abs="$target" ;;
        *)  abs="${hook_cwd:-$repo}/$target" ;;
    esac
    abs="$(realpath -m "$abs")"

    # Out-of-tree writes are guard-write-paths.sh's call, not ours.
    case "$abs" in
        "$repo"/*) rel="${abs#"$repo"/}" ;;
        *) continue ;;
    esac

    ok=0
    for prefix in "${allowed[@]}"; do
        case "$rel" in
            "$prefix"*) ok=1; break ;;
        esac
    done
    [ "$ok" = "1" ] && continue

    if [ "$mode" = "REVIEW" ]; then
        hint="Fixing a review finding is EXECUTE work; landing it is SHIP work.
  /id-execute   (or: bash plugins/id-workflow/hooks/id-state.sh set EXECUTE)
  /id-ship      (or: bash plugins/id-workflow/hooks/id-state.sh set SHIP)"
    else
        hint="If the plan is approved and it is time to implement:
  /id-execute   (or: bash plugins/id-workflow/hooks/id-state.sh set EXECUTE)"
    fi

    deny "[ID:$mode] blocks this write: $rel

ID mode $mode (lane:${lane:-?}) may only write: ${allowed[*]}
PROTOCOL rail 2 — no code or config edits outside EXECUTE/SHIP.

$hint

Then retry. Do not work around the ban by shelling out.

Override for this session only: CLAUDE_ALLOW_ID_WRITES=1"
done <<< "$targets"

exit 0
