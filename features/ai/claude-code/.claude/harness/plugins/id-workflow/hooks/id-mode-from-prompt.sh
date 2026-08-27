#!/usr/bin/env bash
# UserPromptSubmit: set ID mode from what the user typed, before the model sees it.
#
# Why a hook and not just the command body: mode has to be a FACT the guard can
# read, not something the agent remembers to record. Typing /id-plan must move
# the write ban even if the model never gets around to running the state setter.
# The command files still call id-state.sh as a fallback for the case where the
# prompt reaching this hook is already expanded.
#
# Recognised:
#   /id [task...]                -> ORIENT   (entry point, auto-routes after)
#   /id-orient … /id-ship        -> that mode
#   lane:tiny|normal|heavy       -> anywhere in the prompt, sets the lane
#   task:tsk-...                 -> anywhere in the prompt, records the claim
#
#   stdin  : {"hook_event_name":"UserPromptSubmit","prompt":"...","cwd":"..."}
#   stdout : {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit",
#             "additionalContext":"..."}}
set -euo pipefail

input="$(cat)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // empty')"
[ -n "$prompt" ] || exit 0

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

first="$(printf '%s' "$prompt" | sed -E 's/^[[:space:]]+//' | head -1)"

mode=""
case "$first" in
    /id-orient*)   mode="ORIENT" ;;
    /id-research*) mode="RESEARCH" ;;
    /id-plan*)     mode="PLAN" ;;
    /id-execute*)  mode="EXECUTE" ;;
    /id-review*)   mode="REVIEW" ;;
    /id-ship*)     mode="SHIP" ;;
    /id|/id\ *)    mode="ORIENT" ;;
esac

[ -n "$mode" ] || exit 0

args=()
lane="$(printf '%s' "$prompt" | grep -oE '\blane:(tiny|normal|heavy)\b' | head -1 | cut -d: -f2 || true)"
[ -n "$lane" ] && args+=(--lane "$lane")
task="$(printf '%s' "$prompt" | grep -oE '\btsk-[a-z0-9]+-[a-z0-9]+\b' | head -1 || true)"
[ -n "$task" ] && args+=(--task "$task")

summary="$(bash "$here/id-state.sh" set "$mode" "${args[@]}" 2>&1 || true)"

# Project copy of the shared ID pack when there is one, the vendored payload
# copy otherwise. See session-id-context.sh for the reasoning.
repo="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
pack=".cursor/commands/id-workflow"
[ -d "$repo/$pack" ] || pack="$HOME/.claude/id-workflow"

jq -nc --arg ctx "ID workflow: mode is now $summary (set by hook from your prompt).

The write ban for this mode is enforced by plugins/id-workflow/hooks/guard-id-mode.sh — you cannot edit outside the mode's allowed paths, so do not plan around it. Declare '[ID:$mode] lane:...' as the first line of your reply, follow $pack/modes/$(printf '%s' "$mode" | tr '[:upper:]' '[:lower:]').md, and satisfy the matching exit checklist before advancing." \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
