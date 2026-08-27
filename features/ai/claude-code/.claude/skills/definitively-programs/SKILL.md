---
name: definitively-programs
description: Author and edit `.definitively/programs/*.yml` FSM files for the definitively 0.3.x workflow runner — state nodes, node kinds (cli/llm), `outcome:` blocks, signal-to-event mapping, the `on:` transitions, and the `:unknown_outcome` abort path. Use when changing a `pre-commit.yml` / `pre-push.yml` program, adding a new state, hooking a new signal from an LLM or CLI node, debugging `:unknown_outcome can we fix this outcome so it loops back`, or wiring a custom agent into a definitively program.
---

# definitively programs (`.definitively/programs/*.yml`)

`definitively` (Nix store: `/nix/store/<hash>-definitively-0.3.1/bin/definitively`) is the FSM workflow runner that drives the `pre-commit` and `pre-push` programs in this repo. Each program is a YAML state machine: states call **nodes**; nodes emit **outcomes**; outcomes map to **on-event transitions**.

This skill covers how the program contract works and how to author it without triggering `:unknown_outcome`.

## When to use

- Editing `.definitively/programs/pre-commit.yml` or `pre-push.yml` (or any new program in that directory).
- Adding a `fix_*` state that loops on an LLM-fix node.
- Hooking a new signal from an `llm` node into the `outcome:` block.
- Debugging a `:unknown_outcome … can we fix this outcome` error from `definitively run …`.
- Adding a new `cli` node that calls `moon run :target`.

## The contract in 30 seconds

```yaml
program:
  id: <string>             # shown in logs; e.g. "pre_push"
  version: 1               # bump on incompatible schema change
  initial: <state-name>    # passive start state
states:
  <state>:
    type: passive | active | final
    on:                    # event -> next state  (passive + active only)
      <event>: <target>
nodes:
  <node-id>:
    kind: cli | llm
    # kind-specific fields…
    outcome:               # signal-of-this-node -> terminal state event
      success:  - <matcher>
      failure:  - <matcher>
      partial:  - <matcher>
```

The runner resolves a transition like this:

```
(state, node) -> node emits matcher X -> outcome.<X> -> event Y -> state.on.Y -> next state
```

Any of those five mappings being missing or non-matching yields the engine error `:unknown_outcome` (or `:no_outcome_match`). The FSM aborts.

## Node kinds and their outcomes

### `cli` — runs a shell command

```yaml
run_foo:
  kind: cli
  command: ["bash", "-c", "exec moon run :foo -f"]
  timeout_ms: 900000
  outcome: &cli_outcome
    success:  - exit_code: 0
    failure:  - exit_code: {neq: 0}
    partial:  - exit_code: {neq: 0}
```

`cli` nodes resolve exit codes deterministically; `partial` is what the state machine uses to distinguish "needs LLM fix" from "needs user fix". Pick `success` for the green branch, `failure` for "needs the LLM-fix node", and `partial` for "needs human review" — match your state's `on:` accordingly.

### `llm` — invokes an agent

```yaml
llm_fix_foo:
  kind: llm
  agent: hermes
  model: minimax-m3
  prompt_file: .definitively/prompts/fix-foo.md
  timeout_ms: 3600000
  outcome: &llm_outcome
    success:
      - signal: fix_complete        # the agent MUST emit this in its reply
    failure:
      - timeout: true               # agent burned through timeout_ms
      - signal: refused             # agent refused to take the task
```

`llm` nodes terminate by reading a `signal:` marker line in the agent's final response. **The signal must literally appear in the agent's reply text** — typically as the last line, e.g. `Signal: fix_complete`. If the agent runs out of iterations or returns without a signal, the engine reports the node's outcome as `unknown` (not `failure`), and the `on:` block for the state must handle it.

The matcher keys are:

| Matcher key | Meaning |
|-------------|---------|
| `signal: <name>` | Agent's reply contained the literal signal line `Signal: <name>`. |
| `timeout: true` | Node hit `timeout_ms` before completing. |

There is no built-in "iteration cap reached" matcher. When the agent times out by iteration count rather than wall-clock, the outcome resolves to **`unknown`** — not `failure`, not `timeout`.

## The `:unknown_outcome` bug — full story

**Symptom:**

```
11:25:08.947 run_id=run-… node_id=llm_fix_coverage status=unknown exit_code=0 [info] node outcome
11:25:08.947 … state=fix_coverage … outcome=unknown [error] unknown outcome for state
…
workflow failed: :unknown_outcome can we fix this outcome so that it loops back
```

**Root cause:** the `llm_outcome` block lists only `success` and `failure` matchers:

```yaml
outcome: &llm_outcome
  success:  - signal: fix_complete
  failure:  - timeout: true
  - signal: refused
```

If the agent returns neither (e.g. it ran out of iterations and reported `Status: in-progress` without emitting a `Signal:` line), no matcher fires → engine records the outcome as `unknown` → the state's `on:` block has no `unknown:` clause → engine aborts with `:unknown_outcome`.

**Fix:** add `unknown: <target-state>` to the state's `on:` block. The conventional target is the same `fix_*` state (self-loop), so the engine re-enters the LLM node:

```yaml
fix_coverage:
  type: active
  node: llm_fix_coverage
  on:
      success: coverage          # LLM succeeded -> re-run coverage
      failure: fix_coverage      # LLM timed out / refused -> try again
      retry:   fix_coverage      # explicit retry path
      unknown: fix_coverage      # LLM exhausted iterations -> try again
```

Apply this to **every** `fix_*` state in the program that backs an `llm` node. In this repo the canonical pattern lives in both `.definitively/programs/pre-commit.yml` and `.definitively/programs/pre-push.yml`.

## Verifying a program change

```bash
definitively=/nix/store/kf0vwmp1a91wcq2wgdp13kflzwvg0yqi-definitively-0.3.1/bin/definitively

# Loads the program; catches YAML parse errors.
"$definitively" run --help .definitively/programs/pre-push.yml

# Renders the FSM as DOT; spot-check the new edge exists.
"$definitively" visualize .definitively/programs/pre-push.yml \
  --format dot --out /tmp/pre-push-check
grep 'unknown' /tmp/pre-push-check.dot    # should show new self-loop label
```

`definitively validate` is **not** a subcommand in 0.3.1 — the only schema check at edit time is whatever your editor does on YAML. The `--help` form (above) is the cheapest parse check.

## Pitfalls

### `outcome:` keys are a closed set

`success`, `failure`, `partial`, `unknown`, `timeout`. The first three are explicit matcher buckets; the last two are special. Anything else is silently ignored — a typo (`succcess:`) yields the same `:unknown_outcome` abort as no entry at all.

### `signal:` matchers must match literally

The agent's reply must contain the exact line `Signal: <name>` (case-sensitive, with the capital S, colon, and signal name). The agent prompt file should instruct the agent to print this line on its final response. If the prompt's termination pattern is `fix_complete` without the `Signal:` prefix, it will never match.

### `partial` is for "needs a different fix path", not "almost done"

`partial` maps the same matcher as `failure` in this repo's programs (`exit_code: {neq: 0}`) and routes to the same `fix_*` state. The distinction only matters if you later wire a different remediation per outcome — if both `partial` and `failure` go to the same target, just pick one and drop the other.

### Prompts that hit the iter cap emit `unknown`, not `failure`

This is the trap. If a fix-coverage agent burns 90 iterations without converging and ends with `Reached maximum iterations (90). Requesting summary…`, no `Signal:` is emitted, and the engine sees `unknown`. Always include `unknown: <fix-state>` in `on:`. Do **not** rely on the agent to self-recover by re-emitting `fix_complete` after the iteration cap — it has no opportunity to.

### `definitively` is in the Nix store, not on PATH outside devenv

The binary path is fragile across devenv rebuilds. Pin it via the exact `/nix/store/<hash>-definitively-0.3.1/bin/definitively` path or look it up dynamically:

```bash
find /nix/store -maxdepth 3 -name 'definitively' -executable 2>/dev/null
```

There's a memory entry in this repo that records the canonical path for the current devenv generation; cross-check against `devenv.nix` if you suspect drift.

## See also

- `.definitively/programs/{pre-commit,pre-push}.yml` — the live programs in this repo.
- `idclear-git-hooks-config` — the prek layer that emits exit codes and signals consumed by these programs. The two layers' contracts are coupled: if you change `pre-commit` hook output on the prek side, the `cli_outcome` here may need to widen.
- `debug-mantra` — applies when `:unknown_outcome` first surfaces; reproduce with `definitively visualize` before patching.