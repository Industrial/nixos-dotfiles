#!/usr/bin/env bash
# Claude Code port of .cursor/hooks/block-native-*.sh and .hermes/hooks/block-native-tools.sh.
# Routes native file/web tools to the MCP servers (lean-ctx, roam-code, searxng).
#
# Wire protocol differs from Cursor and Hermes:
#   stdin  : {"hook_event_name":"PreToolUse","tool_name":"<name>","tool_input":{...}}
#   stdout : {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#             "permissionDecision":"deny","permissionDecisionReason":"..."}}
#   allow  : exit 0 with no stdout
#
# Escape hatch: CLAUDE_ALLOW_NATIVE_TOOLS=1 disables routing denials, so a
# lean-ctx outage cannot leave the session unable to read or edit anything.
set -euo pipefail

input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // .toolName // empty')"

if [ "${CLAUDE_ALLOW_NATIVE_TOOLS:-0}" = "1" ]; then
    exit 0
fi

deny() {
    jq -nc --arg reason "$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
}

case "$tool_name" in
    Read)
        deny "Native Read is disabled in this repo. Use the lean-ctx MCP tool ctx_read. Modes: full (before edit), map (deps/exports), signatures (API surface), diff (after edit), lines:N-M (range), auto (default). Re-reads are cached (~13 tokens). Do not retry native Read."
        ;;
    Grep)
        deny "Native Grep is disabled in this repo. Use the lean-ctx MCP tool ctx_search. For directory listings use ctx_tree. For symbol/meaning-based exploration use roam-code: roam_search_symbol, roam_context, roam_uses, roam_explore. Do not retry native Grep."
        ;;
    Edit|Write|NotebookEdit)
        deny "Native $tool_name is disabled in this repo. Use the lean-ctx MCP tool ctx_patch: op=replace_unique with path + old_text + new_text to edit, or op=create with path + new_text for a new file. (Some lean-ctx builds also expose ctx_edit; this one does not — ctx_patch is the edit path here.) Scratch files go in .tmp/ at the repo root, never in a /tmp/claude-* scratchpad. Do not retry native $tool_name."
        ;;
    WebSearch)
        deny "Native WebSearch is disabled in this repo. Use the searxng MCP tool searxng_web_search (local SearXNG at http://localhost:4001). Do not retry native WebSearch."
        ;;
    WebFetch)
        deny "Native WebFetch is disabled in this repo. Use the searxng MCP tool web_url_read for general URLs. For library/framework API docs use context7: resolve-library-id then query-docs. Do not retry native WebFetch."
        ;;
esac

exit 0
