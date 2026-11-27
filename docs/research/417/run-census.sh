#!/usr/bin/env bash
# Rerun the #417 S1 census: per host, (1) time a plain toplevel drvPath eval (the baseline the
# Voltaic evaluator must beat) and (2) run census.nix. One host at a time; memory is tight.
# Usage: docs/research/417/run-census.sh [outdir] [host...]   (run from the repo root)
set -euo pipefail
root=$(git rev-parse --show-toplevel)
out=${1:-$root/.tmp/census}
shift || true
hosts=("$@")
[ ${#hosts[@]} -gt 0 ] || hosts=(drakkar mimir huginn muninn)
mkdir -p "$out"
ref="git+file://$root"
timev=/run/current-system/sw/bin/time
for h in "${hosts[@]}"; do
    echo "== $h: toplevel eval" >&2
    "$timev" -v -o "$out/time-eval-$h.txt" \
        nix eval --no-eval-cache --raw "$root#nixosConfigurations.$h.config.system.build.toplevel.drvPath" \
        >"$out/drv-$h.txt"
    echo "== $h: census" >&2
    "$timev" -v -o "$out/time-census-$h.txt" \
        nix eval --no-eval-cache --impure --json --expr \
        "import $root/docs/research/417/census.nix { flakeRef = \"$ref\"; host = \"$h\"; }" \
        >"$out/census-$h.json"
done
