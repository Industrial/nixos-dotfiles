---
name: implement-hierarchical-plan
description: >-
  Executes Maestro-native hierarchical plans from plan-hierarchically with
  maximum parallelization — wave dispatch, MCP claim/verify/ship loop, and
  multi-subagent orchestration. Use when implementing `.cursor/plans/*.plan.md`
  files that have maestro frontmatter, execution overlays, or when the user
  approves a plan and asks to execute, ship, or parallelize wave tasks.
---

# Implement Hierarchical Plan

Turn an approved [plan-hierarchically](../../commands/plan-hierarchically.md) artifact into shipped PRs. **Implementation is orchestration-first**: the parent agent dispatches parallel work; it does not implement wave tasks itself when subagents are available.

## Skills to load first

| Skill | Role |
|-------|------|
| [maestro](../SKILL.md) | Repo read order, heavy-mode loop |
| `~/.claude/skills/maestro-task/SKILL.md` | Claim / verify / ship / split |
| `~/.claude/skills/maestro-verify/SKILL.md` | Witness levels, verdict routing |
| `~/.claude/skills/maestro-handoff/SKILL.md` | Inbox, pickup, cross-session resume |
| [scrutinize](../../engineering/scrutinize/SKILL.md) | Pre-ship self-review |
| Domain skills from the plan's "Skills reviewed" table | e.g. `rust/id_effect/*`, `elixir/*` |

## Prerequisites (reject if missing)

Before claiming any task, confirm the plan has:

- [ ] `.cursor/plans/<slug>.plan.md` with `maestro.mission_id` or `maestro.task_id`
- [ ] `.maestro/specs/<slug>.md` (validated)
- [ ] Heavy mode: `.maestro/missions/<slug>.execution.md` with wave table
- [ ] `maestro plan check` PASS recorded (or run it now)
- [ ] User approval (unless they asked for plan + implementation in one pass)

Read the plan frontmatter and execution overlay before touching code.

## MCP-first rule

Prefer **Maestro MCP** (`project-0-id_effect-maestro` in this repo) for all mission/task/evidence/verdict/handoff/contract operations. Read each tool schema under `mcps/project-0-id_effect-maestro/tools/` before calling — unknown fields fail.

Fall back to `devenv shell -- maestro …` only when no MCP tool exists:

| CLI-only | When |
|----------|------|
| `task verify <tsk>` | Architecture lint gate |
| `plan check --task --plan-file` | Validate plan vs contract |
| `status`, `doctor`, `recover` | Session health |

## Phase 0 — Session bootstrap (parallel MCP)

Run these **in one turn** where independent:

```
maestro_setup_check
maestro_handoff_list { view: "summary" }
maestro_handoff_list { to_agent: "<your-tool-name>" }   # if resuming
maestro_task_list { state: "blocked" }
maestro_task_list { state: "claimed" }
```

If handoff envelopes exist → `maestro_handoff_show` → `maestro_handoff_pickup` before claiming.

Read order:

1. `.maestro/MAESTRO.md` → `.maestro/tasks/NOW.md`
2. Plan file: `.cursor/plans/<slug>.plan.md`
3. Execution overlay: `.maestro/missions/<slug>.execution.md`
4. Active spec: path from plan frontmatter

Locate current wave: first wave whose tasks are not all `shipped`.

## Phase 1 — Parent orchestrator role

The parent agent is a **wave dispatcher**, not a leaf implementer.

| Parent does | Parent does NOT |
|-------------|-----------------|
| Read wave table, pick next executable wave | Implement tasks in a parallel wave |
| Launch N subagents in **one message** | Claim multiple wave tasks on one agent |
| Merge PRs, resolve cross-task conflicts | Skip to wave N+1 before wave N ships |
| Unblock subagents (policy, contract, deps) | Re-plan or widen scope without contract amend |
| Run evidence audit between waves | Ship without verdict PASS |

## Phase 2 — Wave dispatch (maximum parallelization)

For each **parallel wave** row (`Parallel? = yes`), launch **N Task subagents in a single parent message** — one subagent per task slug in that wave.

### Subagent prompt template

Each subagent prompt MUST include:

```
Task: <tsk-id> (<leaf-slug>)
Spec: .maestro/specs/<slug>.md
Plan leaf: .cursor/plans/<slug>.plan.md#<leaf-slug>
Branch: stay on the currently checked-out branch (no Maestro worktree)
Acceptance criteria: <copy from plan leaf — all must-pass>
Gates: <table from plan leaf>
Domain skills: <from plan "Skills reviewed">
Tool name: <cursor | agent id for handoff continuity>

Follow implement-hierarchical-plan skill:
1. CLI: maestro task claim <id> --agent <agent_id> --skip-worktree --tool <tool>
2. maestro_contract_show { taskId }
3. Implement only contract paths; maestro_contract_amend if scope grew
4. Run every gate; maestro_evidence_record after each
5. maestro_policy_check → maestro_verdict_request → maestro_verdict_show (PASS)
6. maestro_task_ship { id, pr_url? }
7. On block: maestro_task_block { id, reason, tool }
```

### Sequential waves (`Parallel? = no`)

Run one subagent (or parent only when subagents unavailable). Do not launch the next wave until the current wave is fully `shipped`.

### Wave gate (mandatory between waves)

Before dispatching wave N+1:

```
maestro_mission_show { mission_id: "pln-..." }
maestro_evidence_list { taskId: "<each wave-N task>", view: "summary" }
```

Confirm every wave-N task is `shipped` and PRs merged (or user-directed integration path documented in overlay).

## Phase 3 — Per-task Maestro loop (MCP)

Every implementer (subagent or solo parent on sequential leaves) runs this loop:

```
# Claim via CLI only — MCP maestro_task_claim always creates heavy worktrees
devenv shell -- maestro task claim <id> --agent <agent_id> --skip-worktree --tool <name>
maestro_contract_show    { taskId }
maestro_policy_check     { taskId }              # before editing
... implement leaf per plan AC + file structure ...
maestro_contract_amend   { taskId, addPaths, reason }   # if legitimate scope growth
maestro_evidence_record  { taskId, command, exitCode }  # after EACH gate
maestro_task_verify      # CLI: devenv shell -- maestro task verify <tsk>
maestro_policy_check     { taskId }              # before verdict
maestro_verdict_request  { taskId }
maestro_verdict_show     { taskId }              # confirm PASS
maestro_task_ship        { id, pr_url? }
```

**Definition of done** = all leaf AC satisfied + all gates recorded + verdict PASS + ship.

## Phase 4 — Intra-task parallelism

When one leaf is still too large for one session:

```
maestro_task_split {
  parent_id: "tsk-...",
  titles: ["slice A", "slice B", "slice C"],
  parallel: true,
  agent_id: "<claimant>"
}
```

Launch one subagent per child in **one message**. Ship all children before shipping parent.

## Phase 5 — Handoffs and blocks

| Situation | MCP action |
|-----------|------------|
| Session resume | `maestro_handoff_list { to_agent: "<tool>" }` |
| Read envelope | `maestro_handoff_show { id: "hnd-..." }` |
| Mark picked up | `maestro_handoff_pickup { id, picked_up_by: "<tool>" }` |
| Mid-stream handoff | `maestro_handoff_emit { task_id, trigger_verb, to_agent, ... }` |
| Blocked | `maestro_task_block { id, reason, tool }` |
| Abandon | `maestro_task_abandon { id, reason, cascade? }` |

Do **not** re-emit handoffs for `claim` / `block` — those emit automatically.

## Phase 6 — Between-wave integration

After a parallel wave ships:

1. Rebase feature branches onto base (`git fetch && git rebase origin/<base>`)
2. Merge PRs in dependency order documented in execution overlay
3. Update parent repo submodule pointers if `.cursor` or other submodules changed
4. Run total quality gate from plan rollup (e.g. `cargo test`, `moon run :check`)
5. Record mission-level evidence if the plan specifies it

Use [pr-lifecycle](../../git/pr-lifecycle/SKILL.md) for branch → PR → CI green per leaf.

## Parallelism decision tree

```
Approved plan exists?
├─ no → stop; run plan-hierarchically first
└─ yes
   └─ Read execution overlay wave table
      ├─ Current wave Parallel? = yes
      │  └─ Launch N Task subagents in ONE message (N = tasks in wave)
      ├─ Current wave Parallel? = no
      │  └─ One subagent OR parent (if subagents unavailable)
      └─ Leaf too large?
         └─ maestro_task_split { parallel: true } → N subagents in ONE message
```

## Reconnaissance during implementation (parallel)

When a leaf touches unfamiliar code, launch parallel subagents **before editing**:

| Track | Tool | Deliverable |
|-------|------|-------------|
| Blast radius | roam `preflight` / `impact` | Symbols and files at risk |
| API surface | roam `search_symbol` / `context` | Existing patterns to follow |
| Repo map | lean-ctx `ctx_read mode=map` | Module boundaries |
| Library docs | context7 `resolve-library-id` + `query-docs` | Unfamiliar deps |

Project into a 5-line delta; do not skip when the plan leaf lists unfamiliar paths.

## Quality bar (reject ship if any fail)

- [ ] `maestro_contract_show` read before first edit
- [ ] Every gate from plan leaf run and `maestro_evidence_record` logged
- [ ] `maestro task verify` exit 0
- [ ] `maestro_verdict_request` → PASS
- [ ] Leaf AC demonstrably satisfied (tests/commands named in plan)
- [ ] Parallel wave used single-message multi-Task dispatch
- [ ] No wave N+1 work started before wave N shipped
- [ ] Plan todo status updated (`pending` → `completed`) as leaves ship

## Anti-patterns

- Parent implements tasks in a parallel wave while subagents are available
- Sequential Task launches for siblings in the same parallel wave
- Claiming multiple wave tasks on one agent without user direction
- Skipping `maestro_contract_show` or `maestro_evidence_record`
- Shipping without `maestro_verdict_request` PASS
- `maestro_task_from_spec` on a `mode: heavy` spec (use mission path)
- Re-planning mid-wave instead of `maestro_task_block` + handoff
- Using CLI when an MCP tool exists for the same operation (exception: always CLI `--skip-worktree` for claim)
- Creating or entering Maestro worktrees / leaving the current branch for claim

## MCP tool quick reference

| Tool | Implementation phase |
|------|---------------------|
| `maestro_setup_check` | Session bootstrap |
| `maestro_handoff_*` | Resume, block, cross-session |
| `maestro_mission_show` | Wave status between waves |
| `maestro_task_list` | Find draft/claimed/blocked tasks |
| `maestro_task_get` | Full leaf detail |
| CLI `maestro task claim … --skip-worktree` | Start leaf on current branch (do not use MCP claim) |
| `maestro_task_split` | Intra-leaf parallel slices |
| `maestro_task_block` / `abandon` | Stop work |
| `maestro_task_ship` | Complete leaf |
| `maestro_contract_show` / `amend` | Scope discipline |
| `maestro_policy_check` | Risk before edit and verdict |
| `maestro_evidence_record` / `list` | Gate audit trail |
| `maestro_verdict_request` / `show` | Pre-ship gate |
| `maestro_principle_promote` | Recurring lint → principle |

## See also

- [plan-hierarchically](../../commands/plan-hierarchically.md) — planning phases 0–8
- [maestro](../SKILL.md) — repo-specific mission context
- `~/.claude/skills/maestro-mission/SKILL.md` — mission decomposition
- Example overlay: `.maestro/missions/fp-algebra.execution.md`
