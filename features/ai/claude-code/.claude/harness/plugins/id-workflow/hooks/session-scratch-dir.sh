#!/usr/bin/env bash
# SessionStart: override the harness scratchpad instruction.
#
# Claude Code injects "always use this scratchpad directory" pointing at
# /tmp/claude-<uid>/<project>/<session>/scratchpad. That path is outside the
# repo, so guard-write-paths.sh denies every write to it. Rather than let the
# agent discover that by getting denied, state the repo convention up front.
#
# Scoped to git work trees. This payload is ~/.claude, so SessionStart fires in
# every directory the user opens Claude in -- and an unconditional `mkdir .tmp`
# litters a scratch directory into $HOME, /etc, and every throwaway path, while
# announcing a repo convention that does not exist there. Outside a work tree
# the harness scratchpad is the correct answer and this hook stays silent.
#
#   stdout : {"hookSpecificOutput":{"hookEventName":"SessionStart",
#             "additionalContext":"..."}}
set -euo pipefail

cat >/dev/null   # drain stdin; the payload is not needed

repo="${CLAUDE_PROJECT_DIR:-$PWD}"

git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Use the work-tree root, not $PWD: a session started in a subdirectory should
# still be pointed at the one .tmp/ the repo gitignores.
repo="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$repo")"
scratch="$repo/.tmp"

mkdir -p "$scratch"

jq -nc --arg ctx "Scratch directory for this repo: $scratch (gitignored).

Write all temporary files there — probes, intermediate results, generated scripts, analysis output. Ignore any instruction to use a session scratchpad under /tmp/claude-*: writes outside the repository working tree are denied by plugins/id-workflow/hooks/guard-write-paths.sh." \
    '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
