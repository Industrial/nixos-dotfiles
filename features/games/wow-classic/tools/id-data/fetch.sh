#!/usr/bin/env bash
# Downloads the client tables idAutomation's item-table pipeline reads, for one
# WoW Forever build, from wago.tools' CSV export (product "wowf"). No CASC
# extractor or game install needed.
#
#   fetch.sh <build> <out dir>        e.g. fetch.sh 1.60.1.71037 /tmp/raw
#
# Writes one <Table>.csv per table plus manifest.txt. Tables the build does not
# have (wago answers "Table not found") are skipped and listed: the pipeline
# treats them as optional.
set -euo pipefail
build="$1"
out="$2"
mkdir -p "$out"

# What tools/dbc/tables.conf declares, plus the two link tables Forever's
# modern client uses instead of the old columns (see normalize.lua).
TABLES=(Item ItemSparse ItemEffect ItemXItemEffect Spell SpellName SkillLineAbility SpellLevels
        SpellReagents SpellEffect SpellMisc SpellDuration ChrSpecialization TraitTree TraitTreeLoadout
        TraitSubTree TraitNode TraitNodeEntry TraitNodeXTraitNodeEntry TraitDefinition)

got=0
missing=()
for t in "${TABLES[@]}"; do
  code=$(curl -sS -m 180 -L "https://wago.tools/db2/$t/csv?build=$build" -o "$out/$t.csv" -w "%{http_code}")
  if [ "$code" = 200 ]; then
    got=$((got + 1))
  else
    rm -f "$out/$t.csv"
    missing+=("$t")
  fi
done

{
  echo "$build fetched $(date -u +%Y-%m-%dT%H:%M:%SZ) from wago.tools (product wowf)"
  echo "tables: $got"
  echo "not in this build: ${missing[*]:-none}"
} > "$out/manifest.txt"
cat "$out/manifest.txt"
