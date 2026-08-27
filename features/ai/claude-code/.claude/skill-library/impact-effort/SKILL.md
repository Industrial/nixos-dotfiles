---
name: impact-effort
description: Plot initiatives on impact vs effort to find quick wins, major projects, fill-ins, and items to avoid. Use for backlog prioritization, roadmap sequencing, and resource allocation when ROI matters more than urgency.
---

# Impact–Effort Prioritization Matrix

## Goal

Maximize value per unit of work by classifying initiatives into four quadrants and sequencing execution accordingly.

Also called **Action Priority Matrix** or **Value vs Effort** matrix.

## When to Use

- Backlog grooming and roadmap planning
- Choosing which tech debt to pay down
- Comparing features with different build costs
- Sprint planning when capacity is fixed

## When NOT to Use

- Urgent incident response (**eisenhower-matrix** adds urgency)
- Deep strategic trade-offs with many criteria (**decision-matrix**)
- When impact cannot be estimated at all (run **cynefin** probe first)

## The Four Quadrants

```
Impact
  ↑
  │  Major Projects    │  Quick Wins
  │  (plan carefully)  │  (do first)
  │────────────────────┼──────────────────
  │  Thankless Tasks   │  Fill-ins
  │  (avoid / defer)   │  (idle time only)
  └────────────────────┴──────────────────→ Effort
```

| Quadrant | Impact | Effort | Strategy |
|----------|--------|--------|----------|
| **Quick Wins** | High | Low | Do immediately; build momentum |
| **Major Projects** | High | High | Plan, staff, milestone; don't start without capacity |
| **Fill-ins** | Low | Low | Batch in slack time; delegate to juniors/automation |
| **Avoid** (Thankless) | Low | High | Decline, descope, or automate; rarely worth manual effort |

## Scoring Rubric for AI Agents

### Impact (1–5)

| Score | Definition |
|-------|------------|
| 5 | Moves primary metric or removes critical risk; affects all users |
| 4 | Significant subset of users or revenue; major dev velocity gain |
| 3 | Moderate measurable improvement |
| 2 | Minor improvement; few users |
| 1 | Negligible; cosmetic |

### Effort (1–5)

| Score | Definition |
|-------|------------|
| 1 | Hours; single file; no dependencies |
| 2 | Days; one engineer; localized |
| 3 | 1–2 weeks; cross-module |
| 4 | Multi-week; multiple engineers; infra changes |
| 5 | Months; architectural; high coordination |

### Classification thresholds

- Impact ≥ 4 and Effort ≤ 2 → **Quick Win**
- Impact ≥ 4 and Effort ≥ 3 → **Major Project**
- Impact ≤ 2 and Effort ≤ 2 → **Fill-in**
- Impact ≤ 2 and Effort ≥ 3 → **Avoid**

Adjust thresholds for team context; document if using 3/3 split.

## Workflow

1. List candidate items (5–20)
2. Score impact and effort independently (avoid "hard = high impact" bias)
3. Plot and label quadrants
4. **Sequence:** Quick Wins → Major Projects (planned) → Fill-ins → Avoid
5. Within Quick Wins: highest `impact/effort` ratio first
6. Challenge Avoid items: can scope reduce effort? Can impact be reframed?

## Output Template

```markdown
## Impact–Effort Matrix — [scope]

| Item | Impact | Effort | Quadrant | Priority |
|------|--------|--------|----------|----------|
| Add retry to webhook | 5 | 2 | Quick Win | 1 |
| Rewrite auth service | 5 | 5 | Major Project | Plan Q3 |

### Execution order
1. ...
### Defer / decline
- ...
```

## Software Engineering Example

| Item | Imp | Eff | Quadrant |
|------|-----|-----|----------|
| Fix flaky CI test | 4 | 1 | Quick Win |
| Migrate to Effect.ts layer | 4 | 4 | Major Project |
| Rename variables for style | 1 | 2 | Fill-in |
| Custom Excel export for 1 user | 2 | 4 | Avoid |

## Common Mistakes

- Confusing **urgency** with **impact** (use Eisenhower for that)
- Underestimating effort of "simple" integration work
- Major Projects without dedicated capacity → perpetual Quick Win churn
- Fill-ins consuming sprint capacity meant for Quick Wins

## Complementary Skills

- **eisenhower-matrix** — urgency × importance overlay
- **decision-matrix** — when Major Projects need multi-criteria comparison
- **confidence-speed-quality** — Quick Wins can ship faster with lower confidence bar
