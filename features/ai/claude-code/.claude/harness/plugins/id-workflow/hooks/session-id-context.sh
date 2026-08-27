#!/usr/bin/env bash
# SessionStart: re-inject ID state so a resume or a compaction cannot drop the rail.
#
# Compaction is the real target. Mid-task the mode lives in .tmp/id/state.json
# and in the model's context; after a compact only the file survives, and an
# agent that has forgotten it is in PLAN will spend its next turns arguing with
# a deny message it does not understand. SessionStart fires with source=compact
# right after, which is the documented place to put context back.
#
# Silent when ID is disengaged.
#
#   stdout : {"hookSpecificOutput":{"hookEventName":"SessionStart",
#             "additionalContext":"..."}}
set -euo pipefail

cat >/dev/null   # drain stdin

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
state="$repo/.tmp/id/state.json"

[ -f "$state" ] || exit 0

mode="$(jq -r '.mode // ""' "$state" 2>/dev/null || true)"
lane="$(jq -r '.lane // ""' "$state" 2>/dev/null || true)"
task="$(jq -r '.task // ""' "$state" 2>/dev/null || true)"
[ -n "$mode" ] || exit 0

mode_lc="$(printf '%s' "$mode" | tr '[:upper:]' '[:lower:]')"

case "$mode" in
    ORIENT|RESEARCH) writes="nothing outside .tmp/" ;;
    PLAN)            writes=".maestro/**, .cursor/plans/**, .tmp/** only" ;;
    REVIEW)          writes=".maestro/**, .tmp/** only" ;;
    EXECUTE|SHIP)    writes="contract-scoped paths in the working tree" ;;
    *)               writes="unknown" ;;
esac

# The ID pack is shared with Cursor and Hermes, so a project that has it wins.
# Projects without a .cursor/ checkout fall back to the copy vendored into the
# payload — without it, a system-wide /id-* would name a playbook that is not
# there.
pack=".cursor/commands/id-workflow"
[ -d "$repo/$pack" ] || pack="$HOME/.claude/id-workflow"

ctx="ID workflow is ENGAGED — this session is mid-pipeline.

  mode: $mode
  lane: ${lane:-unset}
  task: ${task:-none claimed}
  may write: $writes  (enforced by plugins/id-workflow/hooks/guard-id-mode.sh)

Resume where the pipeline left off. Declare '[ID:$mode] lane:${lane:-?}' as the first line of every reply. Playbook: $pack/modes/$mode_lc.md. Rails: $pack/PROTOCOL.md. Satisfy the mode's exit checklist before advancing; do not enter EXECUTE without the human gate. Run '/id-<mode>' to move, or 'bash plugins/id-workflow/hooks/id-state.sh clear' if the work is finished and ID should disengage."

jq -nc --arg ctx "$ctx" \
    '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
