#!/usr/bin/env bash
# Single source of truth for ID workflow state: mode, lane, claimed task.
#
# State lives at .tmp/id/state.json — gitignored, per-checkout, survives a /tmp
# wipe. Read by guard-id-mode.sh (write ban), statusline.sh (display), and
# session-id-context.sh (re-inject after compaction).
#
# The ABSENCE of this file means "ID workflow not engaged": every consumer must
# treat that as full permission, so a session that never types /id behaves
# exactly like an unhooked one.
#
# Usage:
#   id-state.sh set <MODE> [--lane tiny|normal|heavy] [--task tsk-...]
#   id-state.sh get [mode|lane|task|updated]   # no key -> whole JSON
#   id-state.sh show                           # one-line human summary
#   id-state.sh clear                          # disengage ID
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
state_dir="$repo/.tmp/id"
state="$state_dir/state.json"

VALID_MODES="ORIENT RESEARCH PLAN EXECUTE REVIEW SHIP"
VALID_LANES="tiny normal heavy"

die() { printf 'id-state: %s\n' "$1" >&2; exit 1; }

in_list() {
    local needle="$1" list="$2" item
    for item in $list; do [ "$item" = "$needle" ] && return 0; done
    return 1
}

cmd_set() {
    local mode="${1:-}" lane="" task=""
    shift || true
    [ -n "$mode" ] || die "set requires a mode ($VALID_MODES)"
    mode="$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')"
    in_list "$mode" "$VALID_MODES" || die "unknown mode '$mode' (want: $VALID_MODES)"

    while [ $# -gt 0 ]; do
        case "$1" in
            --lane) lane="${2:-}"; shift 2 ;;
            --task) task="${2:-}"; shift 2 ;;
            *) die "unknown flag '$1'" ;;
        esac
    done

    if [ -n "$lane" ]; then
        in_list "$lane" "$VALID_LANES" || die "unknown lane '$lane' (want: $VALID_LANES)"
    fi

    # Carry forward whatever this call did not set.
    local prev_lane="" prev_task=""
    if [ -f "$state" ]; then
        prev_lane="$(jq -r '.lane // ""' "$state" 2>/dev/null || true)"
        prev_task="$(jq -r '.task // ""' "$state" 2>/dev/null || true)"
    fi
    [ -n "$lane" ] || lane="${prev_lane:-normal}"
    [ -n "$task" ] || task="$prev_task"

    mkdir -p "$state_dir"
    jq -nc \
        --arg mode "$mode" \
        --arg lane "$lane" \
        --arg task "$task" \
        --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{mode:$mode, lane:$lane, task:$task, updated:$updated}' \
        > "$state.tmp"
    mv "$state.tmp" "$state"

    cmd_show
}

cmd_get() {
    [ -f "$state" ] || return 0
    if [ $# -eq 0 ]; then
        cat "$state"
    else
        jq -r --arg k "$1" '.[$k] // ""' "$state"
    fi
}

cmd_show() {
    if [ ! -f "$state" ]; then
        echo "ID: disengaged"
        return 0
    fi
    jq -r '"[ID:\(.mode)] lane:\(.lane)" + (if (.task // "") == "" then "" else " task:\(.task)" end)' "$state"
}

cmd_clear() {
    rm -f "$state"
    echo "ID: disengaged"
}

case "${1:-show}" in
    set)   shift; cmd_set "$@" ;;
    get)   shift; cmd_get "$@" ;;
    show)  cmd_show ;;
    clear) cmd_clear ;;
    path)  echo "$state" ;;
    *)     die "unknown subcommand '${1:-}' (set|get|show|clear|path)" ;;
esac
