---
name: first-principles
description: Decompose problems to foundational truths, challenge assumptions with Socratic questioning and Five Whys, then rebuild solutions from verified constraints. Use when analogies fail, inherited designs block innovation, or requirements feel arbitrary.
---

# First Principles Reasoning

## Goal

Strip away convention and analogy until only **verified constraints** remain, then synthesize novel solutions from those constraints.

## When to Use

- "We've always done it this way" blocks better approaches
- Cost, performance, or architecture assumptions feel inflated
- Designing something with no close precedent
- Debugging when symptoms keep recurring despite patches

## When NOT to Use

- Incremental improvements where analogy works fine
- Time-critical fixes (use proven patterns first; revisit later)
- Domains requiring compliance you cannot re-derive (regulations are external constraints, not assumptions)

## Core Concepts

**First principles** = truths that cannot be deduced from other truths in this context:
- Physical laws, mathematical identities
- Verified user needs, measured data
- Hard business constraints (budget, deadline, regulation)
- Proven invariants of the system

**Assumptions** = beliefs treated as true without verification. First-principles work **surfaces and tests** these.

**Analogy** = "X works like Y." Fast but inherits Y's hidden constraints.

## Workflow for AI Agents

### Phase 1 — State the problem precisely

Write one sentence: what must be true when done?

### Phase 2 — List current approach and its assumptions

For each element of the conventional solution, ask:
- Why do we believe this is necessary?
- What evidence supports it?
- What happens if we remove it?

Tag each item: **verified** | **assumption** | **unknown**.

### Phase 3 — Five Whys (for failures or stubborn requirements)

Ask "Why?" up to 5 times until you hit a constraint or a root belief:

```
Symptom: API latency is 2s
Why? → DB query on every request
Why? → No caching layer
Why? → Assumed data must always be fresh
Why? → Product said "real-time"
Why? → Users refresh dashboard manually once per hour  ← constraint reframed
```

Stop when you reach a **fundamental constraint** or **falsifiable claim** to test.

### Phase 4 — Socratic questioning (for design)

Cycle through these question types:

| Type | Question pattern |
|------|------------------|
| Clarify | What exactly do we mean by X? |
| Probe assumptions | What are we taking for granted? |
| Probe evidence | What data supports this? |
| Alternative views | How would X look if Y were false? |
| Implications | If true, what necessarily follows? |
| Meta | Why is this question important? |

### Phase 5 — Extract base constraints

Produce a **constraint list** — only items that survived challenge:

```markdown
## Verified constraints
1. [measurable requirement]
2. [regulatory / security requirement]
3. [physical or logical invariant]

## Removed assumptions
- Was: [assumption] → Actually optional because [reason]
```

### Phase 6 — Rebuild solution space

Generate 2–3 configurations that satisfy **only** verified constraints. Do not re-import discarded assumptions by habit.

### Phase 7 — Validate cheapest hypothesis first

Pick the smallest experiment that falsifies the riskiest assumption.

## Output Template

```markdown
## First Principles Analysis — [problem]

### Problem statement
...

### Assumption audit
| Claim | Status | Evidence |
|-------|--------|----------|
| ... | assumption | none |
| ... | verified | benchmark X |

### Base constraints
1. ...

### Rebuilt options
**Option A:** ... (satisfies constraints 1,2,3)
**Option B:** ...

### Recommended next experiment
...
```

## Software Engineering Example

**Problem:** "We need microservices like Netflix."

| Assumption | Challenge | Constraint |
|------------|-----------|------------|
| Microservices required | Why? | Must scale team independently (verified) |
| 20 services | Why not 3 bounded contexts? | 3 teams, 3 deployables suffices |
| Kafka required | What throughput? | 500 events/sec → Postgres NOTIFY ok |

Rebuild: 3 services, event bus only where measured load requires it.

## Common Mistakes

- Confusing first principles with contrarianism ("opposite of convention")
- Stopping Five Whys at symptoms, not root constraints
- Rebuilding without validating constraints with data
- Spending first-principles effort on reversible, low-stakes choices

## Complementary Skills

- **inversion** — stress-test rebuilt options
- **abstraction-laddering** — zoom out before decomposing
- **issue-trees** — structure assumption audit MECE
- **second-order-thinking** — consequences of rebuilt architecture
