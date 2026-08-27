#!/usr/bin/env bash
# Table-driven tests for the .claude hook layer.
#
#   bash plugins/id-workflow/hooks/test-hooks.sh
#
# Covers: out-of-tree write ban, ID mode write ban per mode, every write-tool
# argument shape, both escape hatches, prompt-driven mode entry, session
# re-injection, and statusline rendering.
#
# Saves and restores any live .tmp/id/state.json, so running the suite mid-task
# does not disturb the session's own ID state.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export CLAUDE_PROJECT_DIR="$repo"

state="$repo/.tmp/id/state.json"
backup=""
if [ -f "$state" ]; then
    backup="$(mktemp)"
    cp "$state" "$backup"
fi

restore() {
    if [ -n "$backup" ]; then
        mkdir -p "$(dirname "$state")"
        cp "$backup" "$state"
        rm -f "$backup"
    else
        rm -f "$state"
    fi
}
trap restore EXIT

pass=0
fail=0

ok()   { pass=$((pass + 1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  \033[31mFAIL\033[0m %s\n     %s\n' "$1" "${2:-}"; }

# Run a PreToolUse hook and echo "allow" or "deny".
verdict() {
    local hook="$1" payload="$2" out
    out="$(printf '%s' "$payload" | bash "$here/$hook" 2>/dev/null || true)"
    if [ -z "$out" ]; then
        echo "allow"
    else
        printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "malformed"'
    fi
}

expect() {
    local want="$1" got="$2" label="$3"
    [ "$want" = "$got" ] && ok "$label" || bad "$label" "wanted $want, got $got"
}

payload() {   # payload <tool> <json-tool-input>
    jq -nc --arg t "$1" --arg cwd "$repo" --argjson ti "$2" \
        '{hook_event_name:"PreToolUse", tool_name:$t, cwd:$cwd, tool_input:$ti}'
}

echo
echo "guard-write-paths.sh — repository confinement"
expect deny  "$(verdict guard-write-paths.sh "$(payload Write '{"file_path":"/tmp/claude-1000/x/scratchpad/probe.js"}')")" "session scratchpad is denied"
expect allow "$(verdict guard-write-paths.sh "$(payload Write "$(jq -nc --arg p "$repo/.tmp/probe.js" '{file_path:$p}')")")" ".tmp/ is allowed"
expect allow "$(verdict guard-write-paths.sh "$(payload Edit '{"file_path":"src/foo.ts"}')")"                                "relative in-tree path is allowed"
expect deny  "$(verdict guard-write-paths.sh "$(payload Edit '{"file_path":"../../../home/tom/.bashrc"}')")"                  "traversal out of the tree is denied"
expect deny  "$(verdict guard-write-paths.sh "$(payload mcp__lean-ctx__ctx_patch '{"ops":[{"path":"a.ts"},{"path":"/etc/hosts"}]}')")" "batch ops: one bad path denies"
expect deny  "$(verdict guard-write-paths.sh "$(payload NotebookEdit '{"notebook_path":"/etc/x.ipynb"}')")"                   "notebook_path is inspected"
expect allow "$(CLAUDE_ALLOW_OUTSIDE_WRITES=1 verdict guard-write-paths.sh "$(payload Write '{"file_path":"/etc/hosts"}')")"  "escape hatch allows out-of-tree"

echo
echo "guard-id-mode.sh — ID disengaged"
rm -f "$state"
expect allow "$(verdict guard-id-mode.sh "$(payload Edit '{"file_path":"src/foo.ts"}')")" "no state file means no ban"

echo
echo "guard-id-mode.sh — write ban per mode"
run_mode() {   # run_mode <MODE> <path> <want>
    bash "$here/id-state.sh" set "$1" --lane normal >/dev/null
    expect "$3" "$(verdict guard-id-mode.sh "$(payload Edit "$(jq -nc --arg p "$2" '{file_path:$p}')")")" "$1: $2 -> $3"
}

run_mode ORIENT   "src/foo.ts"                       deny
run_mode ORIENT   ".tmp/notes.md"                    allow
run_mode RESEARCH "libs/base/src/index.ts"           deny
run_mode RESEARCH ".tmp/id/scratch.json"             allow
run_mode PLAN     "src/foo.ts"                       deny
run_mode PLAN     ".maestro/specs/x.md"              allow
run_mode PLAN     ".cursor/plans/x.md"               allow
run_mode REVIEW   "src/foo.ts"                       deny
run_mode REVIEW   ".maestro/evidence/x.json"         allow
run_mode REVIEW   ".cursor/plans/x.md"               deny
run_mode EXECUTE  "src/foo.ts"                       allow
run_mode SHIP     "src/foo.ts"                       allow

bash "$here/id-state.sh" set PLAN --lane heavy >/dev/null
expect allow "$(CLAUDE_ALLOW_ID_WRITES=1 verdict guard-id-mode.sh "$(payload Edit '{"file_path":"src/foo.ts"}')")" "escape hatch overrides the mode ban"
expect allow "$(verdict guard-id-mode.sh "$(payload Edit '{"file_path":"/etc/hosts"}')")"                          "out-of-tree is left to guard-write-paths"

echo
echo "id-state.sh — state machine"
bash "$here/id-state.sh" set PLAN --lane heavy --task tsk-abc123-xyz >/dev/null
expect "PLAN"          "$(bash "$here/id-state.sh" get mode)" "set then get mode"
expect "heavy"         "$(bash "$here/id-state.sh" get lane)" "lane persisted"
expect "tsk-abc123-xyz" "$(bash "$here/id-state.sh" get task)" "task persisted"
bash "$here/id-state.sh" set EXECUTE >/dev/null
expect "heavy"         "$(bash "$here/id-state.sh" get lane)" "lane carries forward across a mode change"
expect "tsk-abc123-xyz" "$(bash "$here/id-state.sh" get task)" "task carries forward across a mode change"
if bash "$here/id-state.sh" set BOGUS >/dev/null 2>&1; then
    bad "invalid mode is rejected" "set BOGUS succeeded"
else
    ok "invalid mode is rejected"
fi
bash "$here/id-state.sh" clear >/dev/null
[ -f "$state" ] && bad "clear removes state" "state file still present" || ok "clear removes state"

echo
echo "id-mode-from-prompt.sh — mode entry from the prompt"
prompt_payload() { jq -nc --arg p "$1" --arg cwd "$repo" '{hook_event_name:"UserPromptSubmit", prompt:$p, cwd:$cwd}'; }
run_prompt() {   # run_prompt <prompt> <want-mode>
    printf '%s' "$(prompt_payload "$1")" | bash "$here/id-mode-from-prompt.sh" >/dev/null 2>&1
    expect "$2" "$(bash "$here/id-state.sh" get mode)" "prompt '$1' -> $2"
}
run_prompt "/id build the thing"  ORIENT
run_prompt "/id-research"         RESEARCH
run_prompt "/id-plan lane:heavy"  PLAN
expect "heavy" "$(bash "$here/id-state.sh" get lane)" "lane:heavy parsed out of the prompt"
run_prompt "/id-execute tsk-mt8l79jd-rkgzpu" EXECUTE
expect "tsk-mt8l79jd-rkgzpu" "$(bash "$here/id-state.sh" get task)" "task id parsed out of the prompt"
before="$(bash "$here/id-state.sh" get mode)"
printf '%s' "$(prompt_payload "what does this function do?")" | bash "$here/id-mode-from-prompt.sh" >/dev/null 2>&1
expect "$before" "$(bash "$here/id-state.sh" get mode)" "an ordinary prompt does not change mode"

echo
echo "session-id-context.sh — re-injection"
bash "$here/id-state.sh" set REVIEW --lane heavy --task tsk-abc123-xyz >/dev/null
ctx="$(echo '{"hook_event_name":"SessionStart","source":"compact"}' | bash "$here/session-id-context.sh" | jq -r '.hookSpecificOutput.additionalContext')"
case "$ctx" in
    *"mode: REVIEW"*) ok "re-injects the mode" ;;
    *) bad "re-injects the mode" "$ctx" ;;
esac
case "$ctx" in
    *"tsk-abc123-xyz"*) ok "re-injects the claimed task" ;;
    *) bad "re-injects the claimed task" "" ;;
esac
bash "$here/id-state.sh" clear >/dev/null
out="$(echo '{"hook_event_name":"SessionStart","source":"startup"}' | bash "$here/session-id-context.sh")"
[ -z "$out" ] && ok "silent when ID is disengaged" || bad "silent when ID is disengaged" "$out"

echo
echo "statusline.sh"
sl_input='{"model":{"display_name":"Opus 5"},"workspace":{"project_dir":"'"$repo"'","current_dir":"'"$repo"'"}}'
line="$(printf '%s' "$sl_input" | bash "$here/../statusline.sh")"
case "$line" in
    *"Opus 5"*) ok "falls back to the model name when ID is off" ;;
    *) bad "falls back to the model name when ID is off" "$line" ;;
esac
bash "$here/id-state.sh" set EXECUTE --lane heavy --task tsk-abc123-xyz >/dev/null
line="$(printf '%s' "$sl_input" | bash "$here/../statusline.sh")"
case "$line" in
    *"[ID:EXECUTE]"*) ok "renders the mode" ;;
    *) bad "renders the mode" "$line" ;;
esac
case "$line" in
    *"lane:heavy"*) ok "renders the lane" ;;
    *) bad "renders the lane" "$line" ;;
esac
case "$line" in
    *"tsk-abc123-xyz"*) ok "renders the task" ;;
    *) bad "renders the task" "$line" ;;
esac

echo
echo "format-after-edit.sh — targeted formatting"
probe="$repo/.tmp/format-probe.sh"
printf '#!/usr/bin/env bash\necho   "unformatted"\n' > "$probe"
fmt_payload="$(jq -nc --arg cwd "$repo" --arg p "$probe" \
    '{hook_event_name:"PostToolUse", tool_name:"mcp__lean-ctx__ctx_patch", cwd:$cwd, tool_input:{path:$p}}')"
start=$(date +%s%N)
printf '%s' "$fmt_payload" | bash "$here/format-after-edit.sh" >/dev/null 2>&1
elapsed_ms=$(( ($(date +%s%N) - start) / 1000000 ))
[ -f "$probe" ] && ok "survives a ctx_patch payload without error" || bad "survives a ctx_patch payload without error" "probe vanished"
if [ "$elapsed_ms" -lt 10000 ]; then
    ok "formats in ${elapsed_ms}ms (targeted, not a whole-repo sweep)"
else
    bad "formats in ${elapsed_ms}ms" "too slow for a per-edit hook"
fi
missing_payload="$(jq -nc --arg cwd "$repo" '{hook_event_name:"PostToolUse", tool_name:"mcp__lean-ctx__ctx_patch", cwd:$cwd, tool_input:{path:"does/not/exist.ts"}}')"
if printf '%s' "$missing_payload" | bash "$here/format-after-edit.sh" >/dev/null 2>&1; then
    ok "a nonexistent path is a no-op, not an error"
else
    bad "a nonexistent path is a no-op, not an error" "hook exited non-zero"
fi
rm -f "$probe"

echo
echo "stop-verify-gate.sh — turn-end verification"

gate="$here/stop-verify-gate.sh"

# Exit code is the whole contract here: 0 ends the turn, 2 blocks it.
gate_exit() {   # gate_exit <stdin-json> [env assignments...]
    local payload="$1"; shift
    printf '%s' "$payload" | env "$@" bash "$gate" >/dev/null 2>&1
    echo $?
}

gate_probe="$repo/libs/base/__test_stop_gate.ts"
rm -rf "$repo/.tmp/stop-gate"

# The suite runs on whatever tree the developer has. Force the two states we
# care about with a probe file rather than depending on the tree being clean.
printf 'const a = 1\na = 2\nexport default a\n' > "$gate_probe"
expect 2 "$(gate_exit '{}')" "blocks the turn when changed code fails lint"

expect 0 "$(gate_exit '{}' CLAUDE_SKIP_STOP_GATE=1)" "CLAUDE_SKIP_STOP_GATE=1 releases the turn"
expect 0 "$(gate_exit '{"stop_hook_active":true}')" "stop_hook_active short-circuits (no block-on-block loop)"

for mode in ORIENT RESEARCH PLAN REVIEW; do
    bash "$here/id-state.sh" set "$mode" >/dev/null 2>&1
    expect 0 "$(gate_exit '{}')" "$mode skips the gate (recon modes write no code)"
done

bash "$here/id-state.sh" set EXECUTE >/dev/null 2>&1
expect 2 "$(gate_exit '{}')" "EXECUTE gates normally"

# Three blocks on an unchanged tree hands control back rather than spinning.
gate_exit '{}' >/dev/null; gate_exit '{}' >/dev/null
expect 0 "$(gate_exit '{}')" "gives up after 3 blocks on an unchanged tree"

rm -rf "$repo/.tmp/stop-gate"
printf 'const a = 1\nexport default a\n' > "$gate_probe"
expect 0 "$(gate_exit '{}')" "releases the turn once the code passes"

if [ "$(cat "$repo/.tmp/stop-gate/last-pass" 2>/dev/null | wc -c)" -gt 0 ]; then
    ok "records the verified tree so an unchanged turn re-runs nothing"
else
    bad "records the verified tree" "no pass fingerprint written"
fi

start=$(date +%s%N)
gate_exit '{}' >/dev/null
cached_ms=$(( ($(date +%s%N) - start) / 1000000 ))
if [ "$cached_ms" -lt 1000 ]; then
    ok "short-circuits an already-verified tree in ${cached_ms}ms"
else
    bad "short-circuits an already-verified tree in ${cached_ms}ms" "cache not taking effect"
fi

rm -f "$gate_probe"
rm -rf "$repo/.tmp/stop-gate"
expect 0 "$(gate_exit '{}')" "no changed source files is a no-op"

echo
echo "sync-skills.sh — roster vs library"

# Read-only: --check never mutates, so the suite cannot disturb the roster.
sync_out="$(bash "$here/sync-skills.sh" --check 2>&1)"
sync_rc=$?

if [ "$sync_rc" -eq 0 ]; then
    ok ".claude/skills matches the manifest (run sync-skills.sh if this fails)"
else
    bad ".claude/skills matches the manifest" "$(printf '%s' "$sync_out" | head -3)"
fi

if printf '%s' "$sync_out" | grep -q "manifest names no skill provides"; then
    bad "every manifest entry resolves to a real skill" \
        "$(printf '%s' "$sync_out" | sed -n '/manifest names/,+4p' | tail -4 | tr '\n' ' ')"
else
    ok "every manifest entry resolves to a real skill"
fi

lib="$repo/.claude/skills/skill-library/SKILL.md"
if [ -f "$lib" ]; then
    ok "skill-library index exists"
else
    bad "skill-library index exists" "not generated"
fi

# The whole point of the split: nothing may fall out of both tiers.
roster_n="$(printf '%s' "$sync_out" | sed -n 's/.*sync: \([0-9]*\) on the roster.*/\1/p')"
lib_n="$(printf '%s' "$sync_out" | sed -n 's/.*roster, \([0-9]*\) in the library.*/\1/p')"
total_n="$(printf '%s' "$sync_out" | sed -n 's/.*library, \([0-9]*\) total.*/\1/p')"
if [ -n "$total_n" ] && [ "$((roster_n + lib_n))" -eq "$total_n" ]; then
    ok "roster ($roster_n) + library ($lib_n) accounts for every skill ($total_n)"
else
    bad "roster + library accounts for every skill" "$roster_n + $lib_n != ${total_n:-?}"
fi

rows="$(grep -c '^| `' "$lib" 2>/dev/null || echo 0)"
if [ "$rows" -eq "${lib_n:-0}" ]; then
    ok "index carries a row per archived skill ($rows)"
else
    bad "index carries a row per archived skill" "$rows rows for ${lib_n:-?} archived"
fi

if grep -q '(no description)' "$lib" 2>/dev/null; then
    bad "every indexed skill has a description" "some rows fell back to (no description)"
else
    ok "every indexed skill has a description"
fi

dangling=""
for entry in "$repo"/.claude/skills/*; do
    [ -L "$entry" ] || continue
    [ -f "$entry/SKILL.md" ] || dangling="$dangling $(basename "$entry")"
done
if [ -z "$dangling" ]; then
    ok "every roster symlink resolves to a SKILL.md"
else
    bad "every roster symlink resolves to a SKILL.md" "dangling:$dangling"
fi

echo
echo "hooks.json — plugin wiring"

# Claude Code executes a command hook directly, not via `bash <file>`. Every
# other test here invokes scripts through bash, which succeeds regardless of the
# mode bit — so a lost +x passed the whole suite and still broke every hook at
# runtime. That happened once; this test is why it cannot happen twice.
hooks_json="$here/hooks.json"
if [ -f "$hooks_json" ]; then
    ok "hooks.json exists"
else
    bad "hooks.json exists" "no plugin hook wiring at $hooks_json"
fi

not_exec=""
missing=""
while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    script="${cmd//\"\$\{CLAUDE_PLUGIN_ROOT\}\"/$here/..}"
    if [ ! -f "$script" ]; then
        missing="$missing $(basename "$script")"
    elif [ ! -x "$script" ]; then
        not_exec="$not_exec $(basename "$script")"
    fi
done < <(jq -r '..|.command? // empty' "$hooks_json" 2>/dev/null)

[ -z "$missing" ] && ok "every hooks.json command points at a real file" \
    || bad "every hooks.json command points at a real file" "missing:$missing"
[ -z "$not_exec" ] && ok "every hooks.json command is executable" \
    || bad "every hooks.json command is executable" "chmod +x needed:$not_exec"

# The scripts the suite drives but hooks.json does not reference still need +x
# for direct invocation.
aux_not_exec=""
for s in "$here"/*.sh "$here"/../statusline.sh; do
    [ -f "$s" ] && [ ! -x "$s" ] && aux_not_exec="$aux_not_exec $(basename "$s")"
done
[ -z "$aux_not_exec" ] && ok "every harness script is executable" \
    || bad "every harness script is executable" "chmod +x needed:$aux_not_exec"

# SessionStart carries no conversation, so prompt- and agent-type handlers are
# rejected there. Keeping every handler command-typed sidesteps the whole class.
bad_types="$(jq -r '..|.type? // empty' "$hooks_json" 2>/dev/null | sort -u | grep -v '^command$' || true)"
[ -z "$bad_types" ] && ok "every hook handler is command-typed" \
    || bad "every hook handler is command-typed" "found: $(printf '%s' "$bad_types" | tr '\n' ' ')"

if jq -e . "$hooks_json" >/dev/null 2>&1 \
    && jq -e . "$here/../.claude-plugin/plugin.json" >/dev/null 2>&1 \
    && jq -e . "$repo/.claude-plugin/marketplace.json" >/dev/null 2>&1 \
    && jq -e . "$repo/.claude/settings.json" >/dev/null 2>&1; then
    ok "plugin, marketplace and settings JSON all parse"
else
    bad "plugin, marketplace and settings JSON all parse" "one of them is malformed"
fi

# settings.json must not re-declare the hooks the plugin owns, or both fire.
if jq -e '.hooks' "$repo/.claude/settings.json" >/dev/null 2>&1; then
    bad "settings.json declares no hooks" "hooks live in the plugin; duplicates double-fire"
else
    ok "settings.json declares no hooks (plugin is the only wiring)"
fi

echo
printf 'passed %d, failed %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
