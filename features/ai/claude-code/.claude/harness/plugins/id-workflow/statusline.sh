#!/usr/bin/env bash
# Statusline: make ID mode the thing you cannot miss.
#
#   [ID:EXECUTE] lane:heavy · tsk-mt8l79jd · bugfix/ob-rus-address… · ±9
#
# With ID disengaged it degrades to a plain model/branch line rather than
# shouting about a workflow the session is not using.
#
# Hot path budget: this runs on every render, so it reads one JSON file and two
# cheap git plumbing calls (~20ms on this monorepo). Never call `maestro` here —
# `maestro task list --json` costs ~200ms.
set -uo pipefail

input="$(cat)"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Statusline invocations do not reliably carry CLAUDE_PROJECT_DIR, so fall back
# to the workspace block on stdin, then to this script's own location.
repo="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // empty' 2>/dev/null)}"
repo="${repo:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
state="$repo/.tmp/id/state.json"

DIM=$'\033[2m'; RESET=$'\033[0m'
BOLD=$'\033[1m'; CYAN=$'\033[36m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'
SEP="${DIM} · ${RESET}"

parts=()

# ---- ID mode + lane ---------------------------------------------------------
if [ -f "$state" ]; then
    mode="$(jq -r '.mode // ""' "$state" 2>/dev/null)"
    lane="$(jq -r '.lane // ""' "$state" 2>/dev/null)"
    task="$(jq -r '.task // ""' "$state" 2>/dev/null)"

    # Colour by how much damage the mode permits: recon green, plan yellow,
    # write-enabled cyan+bold.
    case "$mode" in
        ORIENT|RESEARCH) mode_colour="$GREEN" ;;
        PLAN|REVIEW)     mode_colour="$YELLOW" ;;
        EXECUTE|SHIP)    mode_colour="${BOLD}${CYAN}" ;;
        *)               mode_colour="$RESET" ;;
    esac
    [ -n "$mode" ] && parts+=("${mode_colour}[ID:${mode}]${RESET}${DIM} lane:${lane}${RESET}")
    [ -n "$task" ] && parts+=("${DIM}${task}${RESET}")
else
    model="$(printf '%s' "$input" | jq -r '.model.display_name // empty' 2>/dev/null)"
    [ -n "$model" ] && parts+=("${DIM}${model}${RESET}")
fi

# ---- branch + dirty count ---------------------------------------------------
branch="$(git -C "$repo" symbolic-ref --short -q HEAD 2>/dev/null || echo detached)"
if [ ${#branch} -gt 28 ]; then
    branch="${branch:0:27}…"
fi
parts+=("${branch}")

dirty="$(git -C "$repo" --no-optional-locks status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')"
[ "${dirty:-0}" -gt 0 ] && parts+=("${YELLOW}±${dirty}${RESET}")

# ---- join -------------------------------------------------------------------
out=""
for p in "${parts[@]}"; do
    [ -z "$out" ] && out="$p" || out="${out}${SEP}${p}"
done
printf '%s' "$out"
