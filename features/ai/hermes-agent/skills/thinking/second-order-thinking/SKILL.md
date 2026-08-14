---
name: second-order-thinking
description: Extend consequence analysis beyond immediate effects by repeatedly asking and then what to surface cascading outcomes, incentives, and long-term risks. Use for strategy, policy, and architectural decisions with delayed effects.
---

# Second-Order Thinking

## Goal

Avoid **first-order optima that are second-order disasters** by chaining consequences until non-obvious effects surface.

Popularized by Howard Marks and Farnam Street; core question: **"And then what?"**

## When to Use

- Strategic and architectural decisions
- Policy changes (pricing, permissions, quotas)
- Incentives and gamification design
- Any decision where effects unfold over weeks/months

## When NOT to Use

- Reversible experiments with fast feedback (**ooda-loop**)
- Purely local refactors with no behavioral impact
- When first-order effect is already catastrophic (address that first)

## Order Definitions

| Order | Description | Example |
|-------|-------------|---------|
| **First** | Direct, immediate result | Lower prices → more sales |
| **Second** | Response to first-order effect | Competitors match → margin war |
| **Third** | Further adaptation | Market consolidation → fewer choices |
| **Nth** | Continue until stable or horizon |

First-order thinking stops at row 1. Second-order continues.

## Workflow for AI Agents

### Step 1 — State the action clearly

"We will [action] in order to [intended first-order effect]."

### Step 2 — First-order effects

List intended and unintended immediate effects. Tag: **intended** | **unintended**.

### Step 3 — Chain "And then what?" (minimum 2 more orders)

For each significant first-order effect, ask:
- Who reacts? How?
- What incentives change?
- What new behaviors emerge?
- What resources get strained?

### Step 4 — Identify feedback loops

Do second-order effects reinforce or dampen the original action? (See **reinforcing-feedback-loop**, **balancing-feedback-loop**.)

### Step 5 — Probability and severity

For each consequential branch:
- Likelihood: low / medium / high
- Severity if occurs: low / medium / high

Focus on **high×high** and **medium×high** paths.

### Step 6 — Decision adjustment

- Proceed as planned
- Proceed with safeguards (monitoring, limits, sunset clauses)
- Redesign action
- Abort

### Step 7 — Document assumptions

Each chain link is conditional on stated assumptions. Falsify assumptions with data where possible.

## Output Template

```markdown
## Second-Order Analysis — [action]

### Action
...

### Consequence chain
| Order | Effect | Intended? | Likelihood | Severity |
|-------|--------|-----------|------------|----------|
| 1st | ... | yes | high | — |
| 2nd | ... | no | medium | high |
| 3rd | ... | no | low | medium |

### Critical paths
1. ...

### Safeguards
- Monitor ...
- Cap ...

### Recommendation
Proceed with safeguards / Redesign because ...
```

## Software Engineering Examples

**Action:** Add aggressive rate limiting on free tier API

| Order | Effect |
|-------|--------|
| 1st | Reduced infra cost; some users throttled |
| 2nd | Power users on free tier churn to competitor |
| 3rd | Fewer free users convert — paid funnel shrinks |

**Action:** Mandate 100% code coverage

| Order | Effect |
|-------|--------|
| 1st | More tests |
| 2nd | Developers write trivial tests; velocity drops |
| 3rd | Critical paths still miss integration failures |

## Common Mistakes

- Stopping at first order ("this saves money" — always ask and then what)
- Inventing fantastical chains without plausible actors
- Ignoring **time delay** (second-order may arrive after you've moved on)
- Analysis paralysis — set depth limit (usually 3 orders sufficient)

## Stopping Rule

Stop chaining when:
- Effects become highly speculative, or
- System reaches apparent equilibrium, or
- 3 orders completed (unless high-stakes)

## Complementary Skills

- **inversion** — failure modes are often second-order
- **iceberg-model** — structures generate second-order patterns
- **connection-circles** — map causal chains visually
- **six-thinking-hats** Black — risks at each order
