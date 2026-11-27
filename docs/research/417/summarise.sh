#!/usr/bin/env bash
# Fold the per-host census-<host>.json and time-*.txt from run-census.sh into the committed,
# docs/research/417/s1-options.json. CI formats JSON with biome, so run
# `bin/ci/lint docs/research/417/s1-options.json` afterwards.
# Usage: docs/research/417/summarise.sh [indir] > docs/research/417/s1-options.json
set -euo pipefail
in=${1:-$(git rev-parse --show-toplevel)/.tmp/census}
hosts=(drakkar mimir huginn muninn)

# Seconds from GNU time's "h:mm:ss" / "m:ss.cc".
timing() {
    awk -F': ' '
    /Elapsed \(wall clock\)/ { n = split($2, a, ":"); s = 0; for (i = 1; i <= n; i++) s = s * 60 + a[i]; wall = s }
    /User time/ { user = $2 } /System time/ { sys = $2 } /Maximum resident/ { rss = $2 }
    END { printf "{\"wall_s\":%s,\"user_s\":%s,\"sys_s\":%s,\"max_rss_mb\":%d}", wall, user, sys, rss / 1024 }' "$1"
}

args=()
for h in "${hosts[@]}"; do
    args+=(--slurpfile "c_$h" "$in/census-$h.json")
    args+=(--argjson "te_$h" "$(timing "$in/time-eval-$h.txt")")
    args+=(--argjson "tc_$h" "$(timing "$in/time-census-$h.txt")")
done

jq -n -c "${args[@]}" '
  def src: split(":")[0];
  # ours if declared in this repo; else repo if any repo definition; else a flake input if
  # any; else nixpkgs.
  def cls: [.d[] | src] as $s
    | if any(.decl[]; startswith("repo:")) then "ours"
      elif any($s[]; . == "repo") then "repo"
      elif any($s[]; . != "nixpkgs" and . != "other") then "input"
      else "nixpkgs" end;
  # Bookkeeping options every imported module defines unconditionally; they say nothing
  # about which modules are active.
  def bookkeeping: .p | test("^(assertions|warnings|meta\\.|documentation\\.)");
  # Upstream modules that contribute a real (non-bookkeeping) winning definition.
  def active: map(select(bookkeeping | not) | .d[] | select(src != "repo")) | unique;
  def ns1:.p | split(".")[0];
  def ns2: .p | split(".") | if length > 2 then .[0:2] | join(".") else .[0] end;
  def tally(f): group_by(f) | map({key: (.[0] | f), value: {
      n: length,
      ours: map(select(cls == "ours")) | length,
      repo: map(select(cls == "repo")) | length,
      input: map(select(cls == "input")) | length,
      nixpkgs: map(select(cls == "nixpkgs")) | length}})
    | from_entries;
  def ownsum: map_values(
      if type == "object" and ((to_entries[0].value // null) | type) == "array"
      then to_entries | group_by(.value | sort | join("+"))
        | map({key: (.[0].value | sort | join("+") | if . == "" then "none" else . end), value: length})
        | from_entries
      else . end);

  {drakkar: $c_drakkar[0], mimir: $c_mimir[0], huginn: $c_huginn[0], muninn: $c_muninn[0]} as $c
  | {drakkar: {e: $te_drakkar, c: $tc_drakkar}, mimir: {e: $te_mimir, c: $tc_mimir},
     huginn: {e: $te_huginn, c: $tc_huginn}, muninn: {e: $te_muninn, c: $tc_muninn}} as $t
  | ($c | to_entries | map(.key as $h | .value.options[] | . + {h: $h})) as $rows
  # Union: one row per option path; an option counts as repo if any host defines it from the repo.
  | ($rows | group_by(.p) | map({p: .[0].p, d: (map(.d[]) | unique), decl: .[0].decl,
      hosts: map(.h)})) as $union
  | {
    meta: {
      issue: "Industrial/nixos-dotfiles#417 S1",
      nixpkgsRev: $c.drakkar.nixpkgsRev,
      repoRev: $c.drakkar.repoRev,
      producedBy: "docs/research/417/run-census.sh + census.nix + summarise.sh",
      defined: "winning priority < 1500 (mkOptionDefault): some module set it beyond the default",
      classes: "ours = option declared in this repo (features.*, profiles.*, ...); repo = upstream option with a definition from this repo; input = else any non-nixpkgs flake input; nixpkgs = only nixpkgs modules"
    },
    hosts: ($c | map_values({
      totalOptions, defined: (.options | length),
      byClass: (.options | group_by(cls) | map({key: (.[0] | cls), value: length}) | from_entries),
      unevaluable: .errors,
      subtrees, ownership: (.ownership | ownsum),
      namespaces: (.options | tally(ns1)),
      activeUpstreamModules: (.options | active | length)
    }) | with_entries(.value += {eval: $t[.key].e, censusEval: $t[.key].c})),
    union: {
      defined: ($union | length),
      byClass: ($union | group_by(cls) | map({key: (.[0] | cls), value: length}) | from_entries),
      onAllHosts: ($union | map(select(.hosts | length == 4)) | length),
      activeUpstreamModules: ($union | active | length),
      namespaces: ($union | tally(ns1)),
      # Upstream (NixOS + inputs) options only: our own features.*/profiles.* are excluded.
      top30: ($union | map(select(cls != "ours")) | tally(ns2) | to_entries | sort_by(-.value.n) | .[0:30]
        | map({ns: .key} + .value))
    },
    # Upstream modules whose options our repo sets: the NixOS surface we drive directly.
    upstreamDriven: ($union | map(select(cls == "repo")) | map(.decl[] as $m | select(($m | src) != "repo")
        | {m: $m, p}) | group_by(.m) | map({module: .[0].m, options: length})
      | sort_by(-.options)),
    # Every file with a real (non-bookkeeping) winning definition, with its option count.
    contributors: ($union | map(select(bookkeeping | not)) | map(.p as $p | .d[] | {f: ., p: $p}) | group_by(.f)
      | map({key: .[0].f, value: length}) | from_entries),
    # Compact union: path -> [hosts initials, class].
    options: ($union | map({key: .p, value: [(.hosts | map(.[0:2]) | join(",")), cls]}) | from_entries)
  }'
