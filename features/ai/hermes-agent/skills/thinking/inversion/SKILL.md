---
name: inversion
description: Solve problems backward — enumerate failure modes, run pre-mortems, and define anti-goals to build robust forward plans. Use for risk mitigation, architecture stress tests, and avoiding predictable mistakes.
---

# Inversion Reasoning

## Goal

Instead of asking "How do I succeed?", ask **"What guarantees failure?"** — then avoid those paths.

Attributed to Charlie Munger: "Invert, always invert."

## When to Use

- Pre-mortems before major launches or migrations
- Architecture and security reviews
- When forward planning feels overconfident
- Defining success criteria (**productive-thinking-model** DRIVE "restrictions")
- Stuck on creative solutions (inverting constraints unlocks options)

## When NOT to Use

- As sole method — pair with forward design
- When failure modes are already exhaustively documented
- Trivial reversible changes (overhead exceeds value)

## Core Techniques

### 1. Goal inversion

| Forward | Inverted |
|---------|----------|
| How do we ship on time? | What would make us miss the deadline certainly? |
| How do we secure this API? | How would an attacker own this system fastest? |

List inverted answers → convert each to **must-not-happen** constraint.

### 2. Pre-mortem (Klein)

Assume the project **failed catastrophically** 6 months from now. Each participant writes **why** it failed. Aggregate failure stories → mitigation plan.

### 3. Anti-goals

Explicit list of outcomes to avoid:
- "We will not break backward compatibility without migration path"
- "We will not add a second source of truth for user identity"

### 4. Inversion for creativity

When stuck: "How would we **maximize** this problem?" → invert those tactics for solutions.

## Workflow for AI Agents

### Step 1 — State forward goal clearly

One sentence: desired end state.

### Step 2 — Invert the question

"What would cause the worst plausible outcome?"

### Step 3 — Brainstorm failure modes (no filtering)

Categories to scan:
- Technical (bugs, scale, security, data loss)
- Process (miscommunication, scope creep, bus factor)
- External (dependency, regulation, market)
- Human (fatigue, skill gaps, wrong incentives)

### Step 4 — Rank by likelihood × severity

Focus mitigations on high-likelihood **or** high-severity items.

### Step 5 — Convert to forward constraints and tests

Each failure mode → either:
- **Prevention** (design constraint)
- **Detection** (monitoring, test)
- **Recovery** (rollback, runbook)

### Step 6 — Rebuild forward plan with guardrails

Forward plan must address top N failure modes explicitly.

## Output Template

```markdown
## Inversion Analysis — [goal]

### Forward goal
...

### Failure modes (inverted)
| # | How it fails | L | S | Mitigation |
|---|--------------|---|---|------------|
| 1 | Deploy without migration | M | H | Blue-green + schema check |

### Anti-goals
- Must not ...

### Updated forward plan
1. ... (addresses failure #1)
```

## Software Engineering Examples

**Migration to new auth provider**

| Failure mode | Mitigation |
|--------------|------------|
| Users locked out | Parallel run; feature flag rollback |
| Session invalidation storm | Gradual cutover by cohort |
| Secret leak in logs | Redact in middleware; audit log config |

**Pre-mortem:** "Launch failed because mobile clients still sent old token format" → add contract test in CI.

## Common Mistakes

- Listing generic failures ("bugs happen") without specific mechanisms
- Inversion without forward synthesis (only doom, no plan)
- Ignoring low-probability catastrophic risks (tail risks)
- Using inversion to justify paralysis (mitigate, don't abort by default)

## Complementary Skills

- **six-thinking-hats** Black hat (risks) — inversion goes deeper with pre-mortem
- **second-order-thinking** — failure modes often appear at 2nd order
- **first-principles** — verify which failure assumptions are real
- **ladder-of-inference** — "they will fail" may be ungrounded belief
