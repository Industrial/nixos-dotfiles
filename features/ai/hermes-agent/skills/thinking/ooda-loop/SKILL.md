---
name: ooda-loop
description: Iterate Observe-Orient-Decide-Act cycles to adapt under uncertainty faster than the environment changes. Use in fast-moving incidents, competitive delivery, and probe-heavy Complex domains.
---

# OODA Loop — Adaptive Decision Cycles

## Goal

Out-cycle uncertainty by **tight feedback loops**: gather signal, update mental model, commit to action, execute, repeat.

Developed by John Boyd (military strategist). Not a one-pass checklist — a **continuous loop**.

## When to Use

- Fast-changing requirements or incidents
- Competitive time pressure (ship, respond, counter)
- Complex domains where each action teaches (pairs with **cynefin-framework** Complex)
- Probing with MVPs or experiments

## When NOT to Use

- Clear-domain SOP execution (just follow the playbook)
- Deep architectural analysis needing weeks of study
- When the cost of wrong action is catastrophic and irreversible (slow down; add gates)

## The Four Phases

| Phase | Purpose | Agent focus |
|-------|---------|-------------|
| **Observe** | Raw signal from environment | Metrics, logs, user feedback, diffs — unfiltered |
| **Orient** | Synthesize into updated model | **Most important phase** — filter, contextualize, challenge prior beliefs |
| **Decide** | Select action among options | Commit; avoid infinite analysis |
| **Act** | Execute; generate new observations | Smallest action that produces learning |

Boyd emphasized **Orient** — culture, experience, and bias shape what we see. Bad orientation → correct Observe, wrong Act.

## Workflow for AI Agents

### Cycle template (repeat until stable)

```
┌─────────────────────────────────────────┐
│  OBSERVE → ORIENT → DECIDE → ACT        │
│     ↑                           │       │
│     └───────────────────────────┘       │
└─────────────────────────────────────────┘
```

### Observe — what to gather

- Current system state (errors, latency, deploy status)
- User/stakeholder signals since last cycle
- Results of previous Act
- **Explicitly note** what you are NOT observing (blind spots)

### Orient — how to synthesize

1. What changed since last cycle?
2. Which prior hypothesis is confirmed/refuted?
3. What domain are we in? (Clear / Complex / Chaotic — see **cynefin-framework**)
4. What biases might filter observations? (use **ladder-of-inference**)
5. Update situational model in 3–5 bullet points

### Decide — commitment rules

- Time-box: if Orient exceeds N minutes, force a decision
- Prefer **reversible** actions in uncertainty
- State hypothesis: "We believe X; Act will show Y"
- Record what would trigger cycle abort or pivot

### Act — execution discipline

- Minimum viable action for maximum learning
- Instrument before acting (metrics, feature flags)
- Timestamp and log decision rationale for next Orient

### Meta — tempo

**Goal:** Complete cycles faster than environment shifts. Shorter cycles in Chaotic; longer in Complicated.

## Output Template

```markdown
## OODA Cycle #[n] — [context]

### Observe
- ...

### Orient (updated model)
- Hypothesis: ...
- Refuted: ...
- Domain: Complex

### Decide
Action: ...
Hypothesis test: if [signal] then [interpretation]
Timebox: 2h

### Act (planned)
1. ...

### Next cycle trigger
- When [metric/event] or [time]
```

## Software Engineering Examples

**Incident:** Error spike after deploy

| Cycle | Observe | Orient | Decide | Act |
|-------|---------|--------|--------|-----|
| 1 | 500 errors/min on /api | Correlates with deploy T-5min | Rollback likely fix | Rollback canary |
| 2 | Errors dropped 90% | Bad commit confirmed | Fix forward vs hold | Hotfix branch |
| 3 | Fix passes CI | Root cause: null guard | Gradual rollout | 10% → 50% → 100% |

**Product:** Unclear feature adoption

| Cycle | Act |
|-------|-----|
| 1 | Ship minimal feature to 5% users |
| 2 | Measure activation; Orient → users drop at step 2 |
| 3 | Act → simplify step 2; repeat |

## Common Mistakes

- Treating OODA as linear (one pass and done)
- Skipping Orient (react to every signal without synthesis)
- Act too large (cannot attribute learning)
- Observe without instrumentation (no feedback for next cycle)
- Slow Decide in Chaotic situations

## Complementary Skills

- **cynefin-framework** — Orient includes domain classification
- **confidence-speed-quality** — Decide tempo vs thoroughness
- **second-order-thinking** — Orient includes consequence chains
