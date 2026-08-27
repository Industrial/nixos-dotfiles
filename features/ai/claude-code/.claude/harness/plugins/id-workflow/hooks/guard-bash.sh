#!/usr/bin/env bash
# Claude Code guard for the Bash tool. Merges three upstream hooks:
#   .hermes/hooks/block-git-branch-delete.sh  (SOUL.md hard rule)
#   .cursor/hooks/block-native-shell.sh       (route shell through ctx_shell)
#   .cursor/hooks/enforce-devenv.sh           (wrap commands in `devenv shell --`)
#
# Order matters. The branch-delete guard is a safety rule, not a routing rule,
# so it runs first and is NOT bypassable by CLAUDE_ALLOW_NATIVE_TOOLS.
set -euo pipefail

input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // .toolName // empty')"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"

[ "$tool_name" = "Bash" ] || exit 0
[ -n "$command" ] || exit 0

deny() {
    jq -nc --arg reason "$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
}

# ---- 1. git branch deletion: always blocked, never bypassable ----------------
cmd_lower="$(printf '%s' "$command" | tr '[:upper:]' '[:lower:]')"
segments="$(printf '%s' "$cmd_lower" | tr ';|&\n' '\n')"

while IFS= read -r segment || [ -n "$segment" ]; do
    segment="$(printf '%s' "$segment" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -z "$segment" ] && continue

    if printf '%s' "$segment" | grep -Eq '\bgit[[:space:]]+branch\b[^;|&]*(-D\b|-d\b|--delete\b)'; then
        deny "Forbidden: never delete git branches (git branch -d/-D/--delete). Ask the user to delete branches manually. See SOUL.md and .hermes/hooks/block-git-branch-delete.sh."
    fi

    if printf '%s' "$segment" | grep -Eq '\bgit[[:space:]]+push\b[^;|&]*(--delete\b|:[^[:space:];|&]+)'; then
        deny "Forbidden: never delete remote git branches (git push --delete or git push :branch). Ask the user to delete branches manually. See SOUL.md and .hermes/hooks/block-git-branch-delete.sh."
    fi
done <<< "$segments"

# ---- 2. tool routing: bypassable via escape hatch ----------------------------
if [ "${CLAUDE_ALLOW_NATIVE_TOOLS:-0}" != "1" ]; then
    deny "Native Bash is disabled in this repo. Use the lean-ctx MCP tool ctx_shell, which applies pattern compression to git/npm/cargo output. Prefer ctx_read/ctx_search/ctx_tree over cat/grep/head/tail for reading code. Do not retry native Bash."
fi

# ---- 3. escape hatch active: require devenv wrapping, where devenv exists ----
#
# This payload is ~/.claude, so the hook runs in every directory the user ever
# opens Claude in -- not just devenv projects. Demanding `devenv shell --` in
# ~, /tmp or any non-devenv repo denies every command with advice that cannot
# be followed there: `devenv shell` fails without a devenv.nix, so the session
# has no working shell at all. Enforce the wrap only where it can succeed.
trimmed="$(printf '%s' "$command" | sed 's/^[[:space:]]*//')"
case "$trimmed" in
    "devenv shell --"*) exit 0 ;;
esac

hook_cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
repo="${CLAUDE_PROJECT_DIR:-${hook_cwd:-$PWD}}"
[ -f "$repo/devenv.nix" ] || exit 0

deny "This workspace requires terminal commands to be wrapped with \"devenv shell --\". Example: devenv shell -- $trimmed"
