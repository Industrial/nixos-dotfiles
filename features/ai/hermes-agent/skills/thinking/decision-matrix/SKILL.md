---
name: decision-matrix
description: Score options against weighted criteria to produce a ranked, auditable recommendation. Use when 3+ options compete on multiple dimensions and gut feel is insufficient.
---

# Weighted Decision Matrix

## Goal

Make trade-offs **explicit, comparable, and defensible** by scoring each option against weighted criteria.

## When to Use

- 3–8 options, 4–8 criteria
- Stakeholders disagree on priorities (weights surface the disagreement)
- Architecture, vendor, or feature selection
- Post-**six-thinking-hats** or **productive-thinking-model** evaluation step

## When NOT to Use

- Two options differing on one obvious axis
- Criteria are not yet defined (do **abstraction-laddering** or **productive-thinking-model** first)
- High uncertainty — need experiments first (**cynefin-framework** Complex)

## Workflow for AI Agents

### Step 1 — Define options

List 3–6 distinct, feasible alternatives. Merge duplicates.

### Step 2 — Define criteria (4–8)

Each criterion must be:
- **Independent** (not double-counting)
- **Scorable** on a defined scale
- **Relevant** to the decision question

Common engineering criteria: maintainability, performance, security, time-to-ship, operational cost, team familiarity, reversibility, user impact.

### Step 3 — Assign weights

Weights sum to **100%** (or 1.0). Document rationale.

| Weight tier | % | When |
|-------------|---|------|
| Critical | 25–35 | Must-have dimension |
| Important | 15–25 | Strong differentiator |
| Minor | 5–15 | Tie-breaker |

**Facilitation tip:** If stakeholders disagree, run matrix with different weight sets (sensitivity analysis).

### Step 4 — Define scoring scale

Use consistent 1–5 scale:

| Score | Meaning |
|-------|---------|
| 5 | Excellent — best expected among options |
| 4 | Good — minor gaps |
| 3 | Adequate — acceptable |
| 2 | Weak — significant concerns |
| 1 | Poor — disqualifying if any critical criterion |

Or 1–10 for finer granularity; stay consistent.

### Step 5 — Score each option × criterion

Score based on **evidence**, not preference. Note assumptions in cells.

### Step 6 — Calculate weighted totals

```
Weighted score = Σ (criterion_weight × option_score)
```

Normalize if using different scales.

### Step 7 — Sensitivity check

- Change top weight ±10% — does winner flip?
- If yes, decision is **fragile** — gather more data or negotiate weights

### Step 8 — Recommend with narrative

Winner + runner-up + **why weights matter** + conditions that would change the pick.

## Output Template

```markdown
## Decision Matrix — [question]

### Options
A, B, C

### Criteria & weights
| Criterion | Weight |
|-----------|--------|
| Security | 30% |
| Time to ship | 25% |
| ... | ... |

### Scores
|  | Security (30%) | TTS (25%) | ... | **Total** |
|--|----------------|-----------|-----|-----------|
| A | 4 (1.20) | 5 (1.25) | ... | **3.85** |
| B | 5 (1.50) | 2 (0.50) | ... | **3.40** |

### Sensitivity
Winner stable unless Security weight < 20%.

### Recommendation
**Option A** — best balance; B wins if security is paramount.
```

## Software Engineering Example

**Choose auth approach:** Session cookies vs JWT vs OAuth-only

| Criterion | Weight | Session | JWT | OAuth-only |
|-----------|--------|---------|-----|------------|
| Security | 30% | 4 | 3 | 5 |
| SSR compatibility | 25% | 5 | 2 | 4 |
| Mobile support | 20% | 3 | 5 | 5 |
| Ops complexity | 15% | 4 | 3 | 2 |
| Team familiarity | 10% | 5 | 4 | 3 |

## Common Mistakes

- Too many criteria (>8) → noise and scoring fatigue
- Correlated criteria (e.g., "quality" and "maintainability")
- Uniform weights when stakeholders have real priorities
- Scoring without evidence (matrix theater)
- Ignoring disqualifiers (score 1 on security may veto regardless of total)

## Complementary Skills

- **hard-choice** — when options are incommensurable, matrix may not apply
- **six-thinking-hats** — Black/Yellow before scoring
- **second-order-thinking** — add criterion for long-term effects
