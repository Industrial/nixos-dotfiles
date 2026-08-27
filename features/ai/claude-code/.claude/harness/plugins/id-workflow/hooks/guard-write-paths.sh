#!/usr/bin/env bash
# Confine every file-writing tool to the repository working tree.
#
# Two problems this solves:
#   1. Claude Code hands each session a scratchpad under /tmp/claude-<uid>/...
#      and tells the agent to use it. This repo has a gitignored .tmp/ instead,
#      so scratch work stays with the checkout and survives a /tmp wipe.
#   2. Writes outside the repo (home dotfiles, sibling checkouts, /etc) are not
#      reviewable in the diff. They should be an explicit, deliberate act.
#
# Runs BEFORE block-native-tools.sh in settings.json so an out-of-tree write
# reports the path problem rather than the tool-routing problem.
#
# Wire protocol:
#   stdin  : {"hook_event_name":"PreToolUse","tool_name":"<name>",
#             "tool_input":{...},"cwd":"..."}
#   stdout : {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#             "permissionDecision":"deny","permissionDecisionReason":"..."}}
#   allow  : exit 0 with no stdout
#
# Escape hatch: CLAUDE_ALLOW_OUTSIDE_WRITES=1 permits out-of-tree writes for a
# session that genuinely needs them (editing ~/.claude, /etc/nixos, ...).
# Deliberately NOT tied to CLAUDE_ALLOW_NATIVE_TOOLS: that one is a routing
# outage valve, this one is a blast-radius decision.
set -euo pipefail

input="$(cat)"

if [ "${CLAUDE_ALLOW_OUTSIDE_WRITES:-0}" = "1" ]; then
    exit 0
fi

deny() {
    jq -nc --arg reason "$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
}

hook_cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
repo="${CLAUDE_PROJECT_DIR:-${hook_cwd:-$PWD}}"
repo="$(realpath -m "$repo")"

# Every argument shape a write tool uses to name its target:
#   Write/Edit          -> file_path
#   NotebookEdit        -> notebook_path
#   ctx_edit/ctx_patch  -> path, ops[].path
#   batch variants      -> paths[]
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

    case "$abs" in
        "$repo"|"$repo"/*) continue ;;
    esac

    deny "Refusing to write outside the repository: $abs (repo root: $repo).

Scratch files, probes, and intermediate output belong in $repo/.tmp/ — it is gitignored and lives with the checkout. Ignore the session scratchpad path under /tmp/claude-*; this repo does not use it.

If the write outside the tree is genuinely intended (editing ~/.claude, /etc/nixos, a sibling checkout), say so and the user can re-run the session with CLAUDE_ALLOW_OUTSIDE_WRITES=1. Do not retry this path."
done <<< "$targets"

exit 0
