---
name: iceberg-model
description: Analyze problems across four levels — Events, Patterns, Structures, Mental Models — to move from reactive fixes to systemic interventions. Use for recurring bugs, organizational dysfunction, and symptoms that keep returning.
---

# Iceberg Model — Systems Analysis

## Goal

Move below visible **events** to **patterns**, **structures**, and **mental models** that generate them — then intervene at the highest-leverage layer possible.

From systems thinking (adapted from Goodman, 2002; widely used in organizational learning).

## When to Use

- Same class of bug/incident keeps recurring
- Quick fixes do not stick
- Organizational or process problems (not single-line code bugs)
- Post-incident review seeking root cause beyond proximate trigger

## When NOT to Use

- One-off typo or isolated mistake
- Need immediate tactical fix only (use iceberg **after** stabilize)
- Problem is fully explained at event level with no recurrence

## The Four Levels

```
        ╱╲
       ╱  ╲     ← EVENTS (visible)
      ╱────╲
     ╱      ╲   ← PATTERNS (trends over time)
    ╱────────╲
   ╱          ╲ ← STRUCTURES (rules, flows, incentives, architecture)
  ╱────────────╲
 ╱              ╲ ← MENTAL MODELS (beliefs, assumptions, culture)
╱________________╲
```

| Level | Question | Examples (engineering) |
|-------|----------|------------------------|
| **Events** | What happened? | Deploy failed; customer churned |
| **Patterns** | What keeps happening? | Deploy fails every Friday; churn after onboarding step 3 |
| **Structures** | What produces the pattern? | No deploy freeze policy; onboarding has no analytics |
| **Mental models** | What beliefs sustain structures? | "Move fast = deploy anytime"; "users will figure it out" |

**Leverage rule:** Interventions higher on the iceberg last longer but take more effort. Event fixes are fast; mental-model shifts are slowest.

## Workflow for AI Agents

### Step 1 — Document the triggering event

Facts only — what, when, who affected, magnitude.

### Step 2 — Patterns (ask over time)

- Has this happened before? How often?
- Is there seasonality, growth correlation, or team correlation?
- Graph or table if data exists

### Step 3 — Structures (ask about system)

- Policies, workflows, architecture, incentives, tooling
- "What makes the pattern rational for someone in the system?"
- Causal links between structural elements

### Step 4 — Mental models (ask about beliefs)

- What must people believe for structures to persist?
- What would have to be believed for the pattern to be *surprising*?

### Step 5 — Identify intervention points

| Level | Intervention type | Effort | Durability |
|-------|-------------------|--------|------------|
| Event | Hotfix, rollback | Low | Low |
| Pattern | Alert, runbook | Medium | Medium |
| Structure | Process change, arch refactor | High | High |
| Mental model | Training, metrics that reshape beliefs | Highest | Highest |

Recommend **at least one** intervention above the event level when recurrence is confirmed.

### Step 6 — Validate downward

After proposing a structural fix, ask: "Would this actually change the observed pattern and events?"

## Output Template

```markdown
## Iceberg Analysis — [problem]

### Events
- [date] ...

### Patterns
- Occurs ~N times per ...
- Correlates with ...

### Structures
- [policy/architecture/incentive] → ...

### Mental models
- "We believe ..." → sustains ...

### Recommended interventions
| Level | Action | Owner | Expected effect |
|-------|--------|-------|-----------------|
| Structure | Add pre-deploy checklist | Eng | Reduce Friday failures |
| Pattern | Weekly deploy health review | Lead | Catch drift early |

### Immediate event response (if needed)
...
```

## Software Engineering Example

**Event:** PagerDuty for DB connection pool exhaustion.

| Level | Finding |
|-------|---------|
| Event | Pool maxed, 503s for 12 min |
| Pattern | 4th occurrence in 2 months; always after marketing email |
| Structure | No connection limit per tenant; emails trigger fan-out queries |
| Mental model | "DB scales infinitely"; no per-tenant quotas |

**Interventions:** Per-tenant pool limits (structure) + load test before campaigns (pattern) + dashboard on pool usage (pattern).

## Common Mistakes

- Stopping at proximate cause ("bug in pool config") when pattern exists
- Jumping to mental models without evidence of recurrence
- Structural changes without metrics to verify pattern broke
- Blaming individuals when structures incentivize the behavior

## Complementary Skills

- **connection-circles** / **reinforcing-feedback-loop** — map structural causality
- **first-principles** — challenge mental models
- **issue-trees** — decompose patterns MECE
- **cynefin-framework** — Complex patterns need probes, not just structure rewrites
