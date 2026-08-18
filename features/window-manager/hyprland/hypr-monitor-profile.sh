#!/usr/bin/env bash
set -euo pipefail
# Switch Odyssey G95NC between 8K ultrawide and 5K ultrawide.
# Usage: hypr-monitor-profile.sh [8k|5k|toggle|status]

OUT="${HYPR_MONITOR_OUTPUT:-DP-1}"
MODE_8K="7680x2160@59.99"
MODE_5K="5120x1440@119.98"

current_mode() {
  hyprctl monitors -j 2>/dev/null | jq -r --arg o "$OUT" '.[] | select(.name==$o) | "\(.width)x\(.height)@\(.refreshRate)"' 2>/dev/null || true
}

apply() {
  local mode="$1"
  hyprctl keyword monitor "$OUT,$mode,auto,1,bitdepth,8"
  notify-send -a Hyprland "Monitor profile" "$OUT -> $mode" 2>/dev/null || true
}

cmd="${1:-status}"
case "$cmd" in
  8k|8K) apply "$MODE_8K" ;;
  5k|5K) apply "$MODE_5K" ;;
  toggle)
    cur="$(current_mode)"
    if [[ "$cur" == 7680x2160* ]]; then apply "$MODE_5K"; else apply "$MODE_8K"; fi
    ;;
  status)
    echo "output=$OUT current=$(current_mode)"
    ;;
  *)
    echo "usage: $0 [8k|5k|toggle|status]" >&2
    exit 2
    ;;
esac
