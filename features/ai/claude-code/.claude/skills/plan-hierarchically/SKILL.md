---
name: plan-hierarchically
description: >
  Produce a Maestro-native hierarchical implementation plan of the highest possible quality before writing or changing any code.
  Planning is the primary deliverable; implementation comes only after the plan is materialized in Maestro, validated, and the user approves.
  When invoked via /id or /id-plan, obeys ID Workflow PROTOCOL.md (mode declaration, write bans, lane).
tags: [planning, maestro, hierarchical, specification, workflow]
---

# Produce a Hierarchical Implementation Plan

## Purpose
Create a high-quality Maestro-native hierarchical implementation plan before writing or changing any code.
Planning is the primary deliverable; implementation follows only after plan materialization, validation, and user approval.

## ID Workflow Integration
When invoked via `/id` or `/id-plan`, this command serves as the PLAN-mode body of the ID Workflow.
Obey `.cursor/commands/id-workflow/PROTOCOL.md` for mode declaration, write bans, and lane settings.

## Core Principles

- For Assay-specific strategic context, see `references/assay-strategic-plan.md`
- **Be concise and direct** - user prefers minimal verbosity and concrete solutions over theoretical discussions
- **Focus on implemented solutions** - value seeing actual code implementations that follow established patterns
- **Match existing code style** - surgical edits only, touch what the task requires
- **Verify changes** - use terminal for builds, tests, and inspection; confirm they pass before claiming work done
- **Establish and respect benchmarks** - define baseline metrics; improvements must enhance performance or functionality without degrading baseline numbers

### Think Before You Act
- Decompose until each leaf is one PR, one session, one verifiable outcome (1 task ↔ 1 PR)
- Ground every claim in evidence: read specs, ADRs, code paths; never invent structure
- Prefer decisions over options: lock choices at the root; open questions only when blocking
- Design for Maestro verification: every leaf must define acceptance criteria, witness level, and gates mappable to `maestro task verify` + `maestro verdict request`
- Parallelize aggressively: reconnaissance and independent wave tasks run as concurrent subagents

## Phases

### Phase 0 — Maestro Bootstrap (Mandatory)
Run in parallel where independent:
- `maestro_setup_check` → harness scaffold ok?
- `maestro_handoff_list { view: "summary" }` → open envelopes from prior agents
- `maestro_task_list { state: "draft" }` → unclaimed work
- `maestro_task_list { state: "blocked" }` → blockers to resolve first
- `maestro_task_list { state: "claimed" }` → in-flight ownership

CLI complements:
- `devenv shell -- maestro status --json`
- `devenv shell -- maestro doctor`
- `devenv shell -- maestro intake --paths <touched-paths>`

Read order after bootstrap:
1. `.maestro/MAESTRO.md` → `.maestro/tasks/NOW.md` → active spec/mission
2. `.maestro/policies/*.yaml` — risk, autopilot, sensitive-paths
3. Existing `.maestro/missions/*.execution.md` — do not contradict wave tables
4. `.cursor/plans/` → avoid duplicate plans

If `maestro_handoff_list` returns envelopes for your tool (`to_agent` filter), run pickup protocol per `maestro-handoff` before planning.

### Phase 1 — Parallel Reconnaissance (Mandatory Subagents)
**Do not draft the plan in the parent agent until reconnaissance completes.**

Launch multiple Task subagents in a single message (minimum tracks):

| Subagent | Goal |
|----------|------|
| Codebase map | Files/modules the change touches; existing patterns to follow |
| Maestro state | Active missions, specs, execution overlays, blocked tasks |
| Blast radius | `roam preflight` / `roam impact` on 2–5 key symbols |
| Dependency docs | Context7 lookup for unfamiliar libraries in the change |

Each subagent prompt must include: goal, paths to search, output format (bullet list + file paths), and **no implementation**.

Parent synthesizes into a **Reconnaissance digest** table:
| Finding | Source | Implication for plan |
|---------|--------|----------------------|

**Do not skip reconnaissance.** A plan without codebase grounding is invalid.
But SCALE THE MECHANISM to the ask: parallel subagents pay off for multi-area
or blast-radius-heavy changes; for a SCOPED single-package/module relocation,
batched targeted parent reads (content search over the moved module names,
import-surface greps, per-file skeleton scans, session_search for prior
campaign context) verify every consumer directly and beat subagent dispatch
on both time and accuracy — every claim lands with a file:line you saw
yourself. Subagents remain mandatory when recon would flood parent context
(hundreds of hits) or spans independent subsystems.

### Phase 2 — Scope, Intake, and Spec

#### 2a. Lock Scope
Restate in one paragraph: goal, in-scope, out-of-scope, assumptions.
Run intake: `devenv shell -- maestro intake --paths <comma-separated-paths>`

Route by lane:
| Lane | Next step |
|------|-----------|
| `tiny` | Single leaf plan; `maestro_task_from_spec` or inline spec |
| `normal` | Light spec → one task |
| `high-risk` | Heavy spec + threat-model evidence requirement |

#### 2b. Author or Load Spec
- **No spec:** load `maestro-design` skill; grill to `.maestro/specs/<slug>.md`; validate
- **Spec exists:** read it; confirm `mode`, `acceptance_criteria`, `non_goals`, `risk_class`

#### 2c. Preview Policy (when task id known)
`maestro_policy_check { taskId: "tsk-..." }`
Record effective risk class and sensitive-path matches in the plan's decision log.

### Phase 3 — Hierarchical Decomposition
Build a tree aligned with Maestro artifacts:
```
Epic (user goal)
├── Phase / milestone (coherent value slice)
│   ├── Work package (1–3 days)
│   │   └── Leaf task → future tsk-… (one PR)
```

**Rules:**
- **Leaves only** carry full detail (sections below). Parents summarize intent, dependencies, rollup AC.
- Each leaf is **MECE** under its parent.
- Order by dependency (topological). Mark **parallel siblings** explicitly — these become wave rows.
- Cap leaf size: one module boundary, one API surface, one migration, one testable behavior.
- Stable IDs: `leaf-env-settings`, `leaf-pipeline-wire`, etc. — match Maestro task slugs.
- Heavy mode (`mode: heavy` in spec): 3+ leaves → mission + execution overlay.
- Light mode: 1 leaf → single `maestro_task_from_spec`.

### Phase 4 — Materialize in Maestro (MCP)

**CLI-only environments:** when the Maestro MCP server is absent but the CLI
binary exists (real case: pinned nix-store path, not on devenv PATH — memory
holds the exact path), materialize through the CLI instead of deviating:
```
maestro mission from-spec .maestro/specs/<slug>.md          # → pln-... (approved)
maestro mission decompose <pln-id> --file /tmp/tasks.json   # batch JSON:
[{"title": "...", "slug": "leaf-..."}, ...]
maestro mission show <pln-id> --json                        # verify children
maestro spec validate .maestro/specs/<slug>.md              # before from-spec
```
This produces the same tracker state as the MCP path (mission approved → planned,
child tasks draft). Verify each step's exit code; devenv noise means grepping the
output for `pln-`/`tsk-` ids, not trusting silence.

#### Heavy mode (multi-PR)
**Option A — from spec (preferred):**
```
maestro_mission_from_spec { spec_path: ".maestro/specs/<slug>.md" }
→ pln-...
maestro_mission_decompose {
  mission_id: "pln-...",
  tasks: [
    { title: "...", slug: "leaf-..." },
    ...
  ]
}
maestro_mission_show { mission_id: "pln-..." }
```

#### Light mode (single PR)
```
maestro_task_from_spec { spec_path: ".maestro/specs/<slug>.md" }
→ tsk-...
maestro_task_get { id: "tsk-..." }
```

#### Execution overlay (heavy mode — mandatory)
Write `.maestro/missions/<slug>.execution.md` with a **wave table**:

```markdown
# Execution overlay: <slug>

| Wave | Tasks (slug) | Parallel? | Blocked by |
|------|--------------|-----------|------------|
| 0    | leaf-a, leaf-b | yes     | —          |
| 1    | leaf-c       | no        | wave 0     |
```

**Rules:**
- Never claim wave N+1 tasks until wave N tasks are `shipped`.
- Parallel wave → one subagent per task, launched in one parent message.
- Sequential chain → `blocked_by` edges in decompose batch or `maestro_task_split` without `parallel`.

### Phase 5 — Plan Document + Validation

Write `.cursor/plans/<slug>.plan.md`:

```yaml
---
name: <Human-readable title>
overview: <One sentence>
maestro:
  mission_id: pln-...   # or task_id: tsk-... for light mode
  spec_path: .maestro/specs/<slug>.md
  execution_overlay: .maestro/missions/<slug>.execution.md  # heavy only
todos:
  - id: leaf-...
    content: <imperative title>
    status: pending
isProject: false
---
```

Then full hierarchical body (see Required content per leaf below).

**Frontmatter pitfall:** the YAML frontmatter MUST open AND close with `---`
lines. When editing an existing plan file, never treat the closing `---` as a
stray separator — deleting it silently breaks the file (editors and gate tools
then see the whole body as part of the YAML doc). Verify after every edit with
a `^---\n...\n^---\n` regex match before running any tool that parses it.

#### Plan-check gate (CLI — no MCP tool)
After the plan file exists and a task is materialized:
```
devenv shell -- maestro plan check --task <tsk-id> --plan-file .cursor/plans/<slug>.plan.md
```

Fix `scope-widens`, `missing-proof`, `risk-class-too-low` before presenting.

**If the gate itself is broken** — fails for EVERY plan file including untouched
sibling missions' files — do not loop reformatting your artifact. Prove the
breakage is pre-existing + orthogonal once, substitute manual verification
against the Quality Bar checklist below, and record the substitution as a
deviation in the execution overlay (doctrine: id-workflow → Tracker-unavailable
fallback). Real case: whole-file YAML multi-document parse error at the
frontmatter close, repo-wide.

Record result:
```
maestro_evidence_record { taskId: "tsk-...", note: "plan-check PASS: <summary>" }
```

### Phase 6 — Self-review Before Presenting
Load `scrutinize` skill on the draft plan:
1. **Intent** — simpler alternative?
2. **Trace** — each leaf's file paths exist?
3. **Verify** — AC falsifiable? Gates real?

Present plan to user. **Do not implement** until approved (unless user asked for both).

When invoked with `/quality`: sharpen AC, tighten scope, resolve ambiguities, re-run plan-check if task exists.

### Phase 7 — Parallel Execution Playbook (Post-approval)

#### Wave dispatch (maximum parallelization)
For each **parallel wave** in the execution overlay, launch **N Task subagents in one message** — one subagent per task in the wave. Each subagent prompt must include:
- `tsk-...` id and leaf AC from the plan
- `spec_path` (heavy mode; do not rely on `worktree_path` — claims use `--skip-worktree`)
- Gates to run before ship
- `tool: "cursor"` (or agent name) for handoff continuity

Parent agent **does not implement wave tasks itself** when subagents are available — orchestrate, merge, unblock.

#### Per-subagent Maestro loop (MCP)
```
maestro_task_claim       { id, agent_id, tool: "<your-tool-name>" }
maestro_contract_show    { taskId }           # read scope before editing
... implement leaf ...
maestro_contract_amend   { taskId, addPaths, reason }   # if scope grew legitimately
maestro_evidence_record  { taskId, command, exitCode }  # after each gate
maestro_policy_check     { taskId }           # before verdict
maestro_verdict_request  { taskId }
maestro_verdict_show     { taskId }           # confirm PASS
maestro_task_ship        { id, pr_url? }
```

#### Intra-task parallelism
When one leaf is still too large:
```
maestro_task_split {
  parent_id: "tsk-...",
  titles: ["slice A", "slice B", "slice C"],
  parallel: true,
  agent_id: "<claimant>"
}
```
Launch one subagent per child; ship children before parent.

### Required Content per Leaf
Every **leaf** MUST include all subsections. No "TBD."

#### 1. Context
- Why this leaf exists; what breaks if skipped
- Current state (verified paths)
- Target state (one paragraph)
- Dependencies (other leaf slugs / `blocked_by`)
- **Maestro:** intended `tsk-` slug, wave number, parallel group

#### 2. Acceptance Criteria
Given/When/Then or numbered **must** statements — objectively checkable. Include negative and edge cases. Map each AC to a test or command.

#### 3. File & Module Structure
- **Create** / **Modify** / **Delete** with purpose
- Tree listing with real paths
- Public API additions explicit
- **Contract paths** for `maestro_contract_show` / amend if non-obvious

#### 4. Diagrams
At least one diagram per **phase**. Control-flow leaves need sequence or state diagrams. Use real module/event names.

| Situation | Diagram type |
|-----------|--------------|
| Module boundaries | `flowchart TB` |
| Request lifecycle | `sequenceDiagram` |
| FSM / workflow | `stateDiagram-v2` |
| Data model | `erDiagram` |
| Rollout / waves | Wave table + dependency graph |

#### 5. Quality Gates
| Gate | Command | Pass | Witness level |
|------|---------|------|---------------|
| Unit | project-specific | 0 failures | agent-claimed-locally |
| Lint/format | `moon run :check` etc. | clean | agent-claimed-locally |
| Integration | named scenario | stated outcome | witnessed-by-ci if CI runs it |
| Maestro verify | `maestro task verify <tsk>` | exit 0 | witnessed-by-maestro |
| Verdict | `maestro_verdict_request` | PASS | witnessed-by-maestro |
| Repo gate | `verify-fast.sh` / definitively gate | exit 0 | witnessed-by-ci |

Record each gate via `maestro_evidence_record`. **Definition of done** = all gates + AC satisfied + `maestro_task_ship`.

#### 6. Implementation Notes
- Patterns to follow (link existing code)
- Error conventions
- Scope traps / anti-patterns
- Changelog if user-visible

#### 7. Risks & Rollback
- Severity, mitigation, feature-flag or revert path

### Phase 8 — Plan-level Rollup
After all leaves:
1. **Executive summary** — 3–5 sentences
2. **Decision log** — locked choices + `maestro_policy_check` risk class
3. **Dependency graph** — mermaid with wave annotations
4. **Recommended order** — leaf slugs with one-line rationale
5. **Parallelism map** — which waves launch N subagents concurrently
6. **Total quality gate** — full-suite command(s)
7. **Out of scope / deferred**
8. **Maestro artifacts produced** — spec path, `pln-`/`tsk-` ids, execution overlay path

## Quality Bar (Self-check)
Reject your draft if any fail:
- [ ] Phase 0 MCP bootstrap ran; handoffs checked
- [ ] Reconnaissance grounded every claim (parallel subagents for multi-area/blast-radius work; scoped batched parent reads acceptable for single-package moves)
- [ ] Every leaf has AC, files, diagrams (where needed), gates — no exceptions
- [ ] Leaf slugs match Maestro task slugs; heavy mode has execution overlay + wave table
- [ ] All 26 Maestro MCP tools considered; each applicable tool invoked or explicitly N/A
- [ ] `maestro plan check` run when task exists
- [ ] Paths verified against repo (roam/lean-ctx — not guessed)
- [ ] Parallel waves map to **single-message multi-Task** dispatch
- [ ] Dependencies acyclic; wave order executable
- [ ] Mid-level engineer could implement any leaf without clarifying questions
- [ ] For Assay-related work, strategic context from `references/assay-strategic-plan.md` has been considered

## Anti-patterns (Do Not)
- Planning without verified grounding (skipping recon entirely is the sin — sequential vs subagent mechanism is a scale decision, see Phase 1)
- Flat bullet lists without hierarchy, wave numbers, or Maestro ids
- Hand-writing heavy specs without `maestro-design` grill
- `maestro_task_from_spec` on a `mode: heavy` spec (orphan task — use mission path)
- Claiming multiple wave tasks on one agent when subagents are available
- Sequential Task launches when tasks are in the same parallel wave
- Skipping `maestro_contract_show` before editing scoped tasks
- Skipping `maestro_evidence_record` / `maestro_verdict_request` before ship
- Re-emitting handoffs for claim/block (already automatic)
- Starting implementation before plan-check PASS and user approval
- Using CLI when MCP tool exists for the same operation

## When the User Attaches Modifiers
| Modifier | Action |
|----------|--------|
| `/skills` | List all skills reviewed (table in Skills section) before continuing |
| `/quality` | Re-read request + this command; sharpen AC, scope, diagrams, gates; re-run plan-check if task exists |
| `/scientific-method` | For optimization/trade-off leaves: observations, ranked hypotheses, falsification-first experiments in the plan |
| `/scrutinize` | Outsider review of the plan before presenting |
| `/id` / `/id-plan` | Prefer ID Workflow PLAN mode; this file remains the PLAN body |