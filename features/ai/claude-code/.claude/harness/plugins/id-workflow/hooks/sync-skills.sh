#!/usr/bin/env bash
# Reconcile .claude/skills/ against .claude/skills.manifest, and index everything
# the manifest leaves out into the `skill-library` skill.
#
#   bash sync-skills.sh           apply
#   bash sync-skills.sh --check   exit 1 if out of sync (CI)
#
# The problem this solves: skills are cheap individually and expensive in bulk.
# Claude Code loads every skill's name and description at session start, and at
# 210 entries the roster overflowed — most descriptions were dropped, leaving
# bare slugs the model cannot match a task against. There are 262 skills in this
# payload, so a split is not optional.
#
# The fix is one more level of the progressive disclosure that skills already
# use. Tier 1 is the manifest: on the roster, auto-invocable, in .claude/skills/.
# Tier 2 is everything else, sitting in .claude/skill-library/ as real content
# and indexed by name and description inside skill-library/SKILL.md — which
# costs nothing until invoked, and then hands over the exact path to read.
#
# What changed when the payload moved into ~/.dotfiles: this script used to
# create SYMLINKS from .claude/skills/ into .cursor/ and .hermes/, and resolved
# its root with `git rev-parse`. Both are wrong now. The payload is symlink-free
# by design — every skill is vendored real content — so promotion and demotion
# are `mv` between two directories, and the root is derived from this file's own
# location. `git rev-parse` would land on the dotfiles root and look for a
# .claude/ that is not there.
#
# Nothing is ever deleted. Demoting a skill moves it to tier 2; the content is
# identical either way. Reverting is a line in the manifest and a re-run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# hooks/ -> id-workflow/ -> plugins/ -> harness/ -> .claude/
payload="$(cd "$here/../../../.." && pwd)"

manifest="$payload/skills.manifest"
roster="$payload/skills"
library="$payload/skill-library"
index="$roster/skill-library"

check_only=0
[ "${1:-}" = "--check" ] && check_only=1

[ -f "$manifest" ] || {
    echo "no manifest at $manifest" >&2
    exit 1
}
[ -d "$library" ] || {
    echo "no skill library at $library — run bin/vendor-skills first" >&2
    exit 1
}

mkdir -p "$roster"

# --- what the manifest asks for ----------------------------------------------
wanted="$(mktemp)"
have="$(mktemp)"
trap 'rm -f "$wanted" "$have"' EXIT

grep -v '^[[:space:]]*#' "$manifest" | grep -v '^[[:space:]]*$' |
tr -d '[:blank:]' | sort -u >"$wanted"

find "$roster" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -u >"$have"

drift=0

# --- promote -----------------------------------------------------------------
# In the manifest, not on the roster. skill-library is generated below, so it is
# never promoted from tier 2.
while read -r name; do
    [ "$name" = "skill-library" ] && continue
    [ -d "$roster/$name" ] && continue

    if [ -d "$library/$name" ]; then
        echo "promote $name"
        drift=1
        [ "$check_only" -eq 1 ] || mv "$library/$name" "$roster/$name"
    else
        echo "MISSING $name — in the manifest but in neither tier" >&2
        drift=1
    fi
done <"$wanted"

# --- demote ------------------------------------------------------------------
# On the roster, not in the manifest.
while read -r name; do
    [ "$name" = "skill-library" ] && continue
    grep -qx "$name" "$wanted" && continue

    echo "demote $name"
    drift=1
    if [ "$check_only" -eq 0 ]; then
        rm -rf "${library:?}/$name"
        mv "$roster/$name" "$library/$name"
    fi
done <"$have"

# --- the index ---------------------------------------------------------------
# Regenerated from whatever is in tier 2 right now. Paths are the post-switch
# ones (~/.claude/...), which is where the payload lives once bin/link-files-nixos
# has run; before that they are inert, which is expected.
description_of() {
    # First non-empty line of the front-matter description, folded to one line.
    # Descriptions are frequently YAML block scalars (`description: >-`), so the
    # continuation lines matter and a plain grep would return an empty string.
    awk '
    /^description:[[:space:]]*$/ || /^description:[[:space:]]*[>|]/ { collecting = 1; next }
    /^description:[[:space:]]*/ { sub(/^description:[[:space:]]*/, ""); print; exit }
    collecting && /^[[:space:]]+[^[:space:]]/ { sub(/^[[:space:]]+/, ""); printf "%s ", $0; next }
    collecting { print ""; exit }
  ' "$1" | head -c 400 | tr -s '[:space:]' ' ' | sed 's/[[:space:]]*$//'
}

generated="$(mktemp)"
{
    echo "---"
    echo "name: skill-library"
    printf 'description: >-\n'
    printf '  Index of %s specialist skills held off the default roster.\n' \
        "$(find "$library" -mindepth 1 -maxdepth 1 -type d | wc -l)"
    printf '  Every one is present as real content under ~/.claude/skill-library/ and is read\n'
    printf '  directly by path — nothing here needs installing or fetching. Invoke when a task\n'
    printf '  needs expertise outside the default roster, or to check whether a skill exists\n'
    printf '  before concluding none does.\n'
    echo "---"
    echo
    echo "# Skill library"
    echo
    echo "These skills are **not** on the session roster, which is bounded so that every listed"
    echo "skill keeps its description. They are otherwise ordinary skills: real directories, full"
    echo "content, no fetching. Read the path given for the one you need."
    echo
    echo "To put one on the roster permanently, add its name to \`~/.claude/skills.manifest\` and"
    echo "re-run \`sync-skills.sh\`. It moves between the two directories; nothing is copied, so the"
    echo "two tiers cannot drift."
    echo
    echo "| Skill | Description |"
    echo "|---|---|"

    find "$library" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | while read -r name; do
        desc="$(description_of "$library/$name/SKILL.md" 2>/dev/null)"
        [ -n "$desc" ] || desc="(no description)"
        printf '| `%s`<br>`~/.claude/skill-library/%s/SKILL.md` | %s |\n' \
            "$name" "$name" "${desc//|/\\|}"
    done
} >"$generated"

if [ ! -f "$index/SKILL.md" ] || ! cmp -s "$generated" "$index/SKILL.md"; then
    echo "regenerate skill-library index"
    drift=1
    if [ "$check_only" -eq 0 ]; then
        mkdir -p "$index"
        cp "$generated" "$index/SKILL.md"
    fi
fi
rm -f "$generated"

# --- report ------------------------------------------------------------------
roster_count="$(find "$roster" -mindepth 1 -maxdepth 1 -type d | wc -l)"
library_count="$(find "$library" -mindepth 1 -maxdepth 1 -type d | wc -l)"
links="$(find "$payload" -type l | wc -l)"

echo "tier 1 (roster):  $roster_count"
echo "tier 2 (library): $library_count"
echo "symlinks:         $links"

if [ "$links" -ne 0 ]; then
    echo "the payload must contain no symlinks" >&2
    exit 1
fi

if [ "$check_only" -eq 1 ] && [ "$drift" -ne 0 ]; then
    echo "out of sync with the manifest" >&2
    exit 1
fi

exit 0
