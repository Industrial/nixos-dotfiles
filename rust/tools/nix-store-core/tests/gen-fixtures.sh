#!/usr/bin/env bash
# Generate nix-store-core golden fixtures from this machine's C++ Nix.
# usage: tests/gen-fixtures.sh tests/fixtures   (from rust/tools/nix-store-core, with nix, jq)
set -euo pipefail
export LC_ALL=C
out="$1"; mkdir -p "$out"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

# ---- store paths: from the running system's closure, small NARs, with a deriver
nix-store -qR /run/current-system > "$work/closure"
xargs nix path-info --json < "$work/closure" | jq -s add > "$work/info.json"
jq -r 'to_entries[] | select(.value.narSize <= 4194304 and .value.deriver != null and .value.ca == null)
       | [(.value.signatures | length > 0), .key] | @tsv' "$work/info.json" \
    | sort -k2 > "$work/cands"
# 45 signed and 15 locally built, spread evenly over the sorted candidates.
pick() { awk -v want="$2" -v s="$1" -F'\t' '$1==s {a[n++]=$2} END {step = n/want; if (step<1) step=1; for (i=0; i<want && int(i*step)<n; i++) print a[int(i*step)]}' "$work/cands"; }
{ pick true 45; pick false 15; } | sort -u > "$work/picked"
echo "picked $(wc -l < "$work/picked") store paths"

entries=()
while read -r p; do
    sri="$(nix hash path "$p")"
    want="$(jq -r --arg p "$p" '.[$p].narHash' "$work/info.json")"
    [[ "$sri" == "$want" ]] || { echo "nix hash path disagrees with path-info for $p" >&2; exit 1; }
    b16="$(nix hash convert --hash-algo sha256 --to base16 "$sri")"
    n32="$(nix hash convert --hash-algo sha256 --to nix32 "$sri")"
    nix-store -qR "$p" | sort > "$work/qr"
    csize="$(wc -l < "$work/qr")"
    csha="$(sha256sum < "$work/qr" | cut -d' ' -f1)"
    jq -c --arg p "$p" --arg b16 "$b16" --arg n32 "$n32" --argjson csize "$csize" --arg csha "$csha" \
        --rawfile qr "$work/qr" \
    '.[$p] | {path: $p, narHash, narHashBase16: $b16, narHashNix32: $n32, narSize,
               references, deriver, signatures, ca, closureSize: $csize, closureSha256: $csha}
            + (if $csize <= 8 then {closure: ($qr | split("\n") | map(select(. != "")))} else {} end)' \
        "$work/info.json" > "$work/e.$csha.json"
    entries+=("$work/e.$csha.json")
done < "$work/picked"
jq -s --arg nix "$(nix --version)" '{nix: $nix, storePaths: .}' "${entries[@]}" > "$out/paths.json"

# ---- derivations: small .drv files in one system's build closure, ATerm text embedded
d="$(jq -r '[to_entries[] | select(.key | test("-bash-interactive-")) | .value.deriver] | first' "$work/info.json")"
nix-store -qR "$d" | grep '\.drv$' > "$work/drvs"
while read -r f; do
    s="$(stat -c %s "$f")"
    if (( s >= 500 && s <= 2600 )); then echo "$f"; fi
done < "$work/drvs" | sort > "$work/smalldrvs"
total="$(wc -l < "$work/smalldrvs")"
awk -v n="$total" -v want=56 'BEGIN{step=n/want} {a[NR-1]=$0} END{for(i=0;i<want;i++) print a[int(i*step)]}' "$work/smalldrvs" > "$work/drvpick"
echo "picked $(wc -l < "$work/drvpick") of $total small derivations"
dentries=()
i=0
while read -r f; do
    nix derivation show "$f" > "$work/show.json"
    jq -c --arg f "$f" --rawfile aterm "$f" \
    '.[$f] | {path: $f, aterm: $aterm, system, builder, args, env, inputSrcs,
              structuredAttrs: (.structuredAttrs // null),
              inputDrvs: (.inputDrvs | map_values(.outputs)),
              outputs: (.outputs | map_values(
                {path: (.path // ""),
                 hashAlgo: (if .hashAlgo == null then ""
                            elif .method == "nar" then "r:" + .hashAlgo
                            elif .method == "text" then "text:" + .hashAlgo
                            else .hashAlgo end),
                 hash: (.hash // "")}))}' "$work/show.json" > "$work/d.$i.json"
    dentries+=("$work/d.$i.json"); i=$((i+1))
done < "$work/drvpick"
jq -s '{derivations: .}' "${dentries[@]}" > "$out/drvs.json"

# ---- a synthetic tree, so the NAR format is checked where the store is not this one
t="$work/tree"
mkdir -p "$t/bin" "$t/sub/deeper" "$t/emptydir"
printf 'hello\n' > "$t/a.txt"
printf '#!/bin/sh\necho hi\n' > "$t/bin/run"
: > "$t/empty"
printf 'z' > "$t/sub/deeper/z"
printf 'B' > "$t/B"
printf '%s' 'exactly8' > "$t/eight"
ln -s a.txt "$t/link"
ln -s ../a.txt "$t/sub/up"
chmod 0644 "$t/a.txt" "$t/empty" "$t/sub/deeper/z" "$t/B" "$t/eight"
chmod 0755 "$t/bin/run"
jq -n --arg h "$(nix hash path "$t")" --argjson s "$(nix-store --dump "$t" | wc -c)" '{narHash: $h, narSize: $s}' > "$out/nar-tree.json"
ls -la "$out"
