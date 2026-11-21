#!/usr/bin/env bash
# Write a golden case for two store paths on this machine: both closures, the
# selected sets nvd computes, the closure sizes, and nvd's own output.
#
#   tests/gen-fixture.sh <old> <new> tests/fixtures/drakkar-<what>.json
#
# Needs nix-store, nix, nvd and jq. Reads only.
set -euo pipefail
(($# == 3)) || {
    echo "usage: $0 <old> <new> <out.json>" >&2
    exit 2
}
old="$1" new="$2" out="$3"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

side() { # side <path> <selected-root> <tag>
    local root
    root="$(readlink -f "$1")"
    nix-store -qR "$root" | sed 's|^/nix/store/||' | sort >"$tmp/$3.paths"
    nix-store -q --references "$(readlink -f "$2")" | sed 's|^/nix/store/||' | sort >"$tmp/$3.selected"
    nix path-info --closure-size "$root" | awk '{print $NF}' >"$tmp/$3.size"
    echo "$root" >"$tmp/$3.root"
}

# nvd's selected sets: `sw`'s references when both sides have one, else the root's.
if [[ -d "$old/sw" && -d "$new/sw" ]]; then
    side "$old" "$old/sw" old
    side "$new" "$new/sw" new
else
    side "$old" "$old" old
    side "$new" "$new" new
fi
nvd --color=never diff "$old" "$new" >"$tmp/nvd.txt"

comm -12 "$tmp/old.paths" "$tmp/new.paths" >"$tmp/common"
comm -23 "$tmp/old.paths" "$tmp/new.paths" >"$tmp/old.only"
comm -13 "$tmp/old.paths" "$tmp/new.paths" >"$tmp/new.only"

jq -n \
    --rawfile common "$tmp/common" \
    --arg oldLabel "$old" --arg newLabel "$new" \
    --arg oldRoot "$(cat "$tmp/old.root")" --arg newRoot "$(cat "$tmp/new.root")" \
    --rawfile oldOnly "$tmp/old.only" --rawfile newOnly "$tmp/new.only" \
    --rawfile oldSel "$tmp/old.selected" --rawfile newSel "$tmp/new.selected" \
    --argjson oldSize "$(cat "$tmp/old.size")" --argjson newSize "$(cat "$tmp/new.size")" \
    --rawfile nvd "$tmp/nvd.txt" \
'def lines: split("\n") | map(select(. != ""));
   {common: ($common | lines),
    old: {label: $oldLabel, root: $oldRoot, only: ($oldOnly | lines), selected: ($oldSel | lines), narSize: $oldSize},
    new: {label: $newLabel, root: $newRoot, only: ($newOnly | lines), selected: ($newSel | lines), narSize: $newSize},
    nvd: $nvd}' >"$out"
echo "wrote $out"
