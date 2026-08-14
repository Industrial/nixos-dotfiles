---
name: eisenhower-matrix
description: Prioritize tasks by importance and urgency into four quadrants with explicit scoring, handling strategies, and sequencing rules. Use for work triage, scheduling, and deciding what to do now vs later vs never.
---

# Eisenhower Matrix Prioritization

## Goal

Sort candidate tasks into four quadrants so the agent allocates attention to **strategic work** (important, not urgent) instead of drowning in reactive busywork.

## When to Use

- Multiple competing tasks with limited time
- Backlog triage before sprint planning
- Deciding whether to interrupt current work for a new request
- Weekly or daily planning sessions

## When NOT to Use

- Choosing between technical architectures (use **decision-matrix**)
- Estimating ROI of features (use **impact-effort**)
- When only one task exists and is clearly blocking

## Core Concepts

| Quadrant | Important? | Urgent? | Strategy |
|----------|------------|---------|----------|
| **Q1: Do Now** | Yes | Yes | Execute immediately; protect calendar |
| **Q2: Schedule** | Yes | No | Block dedicated time; highest long-term ROI |
| **Q3: Delegate / Defer** | No | Yes | Automate, delegate, batch, or defer with SLA |
| **Q4: Eliminate** | No | No | Drop, ignore, or say no |

**Importance** = contribution to goals, outcomes, or risk reduction.
**Urgency** = time sensitivity, deadlines, or blocking others.

Covey's insight: most value lives in **Q2** (important, not urgent). Chronic Q1 firefighting signals missing Q2 investment.

## Workflow for AI Agents

### Step 1 — Define the decision horizon

State the time window (today, this sprint, this week). Score tasks only within that horizon.

### Step 2 — Score each task (1–5 each axis)

**Importance (1–5)**
- 5: Directly advances primary goal or prevents critical failure
- 4: Significant stakeholder or system impact
- 3: Moderate value; supports goals indirectly
- 2: Nice-to-have; minor impact
- 1: No meaningful impact on stated goals

**Urgency (1–5)**
- 5: Due today or blocking production/others now
- 4: Due within 48 hours or blocking a near-term milestone
- 3: Due this week
- 2: Flexible timing; soft deadline
- 1: No deadline; can wait indefinitely

### Step 3 — Classify

- Importance ≥ 3 **and** Urgency ≥ 3 → **Q1 Do Now**
- Importance ≥ 3 **and** Urgency ≤ 2 → **Q2 Schedule**
- Importance ≤ 2 **and** Urgency ≥ 3 → **Q3 Delegate/Defer**
- Importance ≤ 2 **and** Urgency ≤ 2 → **Q4 Eliminate**

Use ≥3 as threshold; adjust to 4 for stricter triage.

### Step 4 — Assign handling strategy per quadrant

| Quadrant | Agent actions |
|----------|---------------|
| Q1 | Execute now; minimize context switches; report blockers immediately |
| Q2 | Propose calendar slot or sprint commitment; never leave unscheduled |
| Q3 | Suggest automation, delegation target, batch window, or defer date |
| Q4 | Recommend dropping with brief rationale; ask user to confirm |

**Solo worker (no delegate):** Q3 → automate, defer with explicit date, or reduce scope.

### Step 5 — Sequence Q1 and Q2

Within Q1: highest `(importance × urgency)` first.
Within Q2: highest importance first; schedule before Q3 work.

### Step 6 — Revisit weekly

Re-score tasks; items stuck in Q1 often belong in Q2 (prevention) or Q4 (false urgency).

## Output Template

```markdown
## Eisenhower Triage — [horizon]

| Task | Imp | Urg | Quadrant | Action |
|------|-----|-----|----------|--------|
| ... | 5 | 5 | Q1 | Execute now |
| ... | 5 | 2 | Q2 | Schedule Thu 2h block |

### Recommended sequence
1. ...
2. ...

### Eliminate / defer candidates
- ...
```

## Software Engineering Example

| Task | Imp | Urg | Quadrant | Action |
|------|-----|-----|----------|--------|
| Production auth bug | 5 | 5 | Q1 | Fix now |
| Refactor payment module tests | 4 | 1 | Q2 | Schedule next sprint |
| Slack ping about doc typo | 1 | 4 | Q3 | Batch end of day |
| Rewrite unrelated legacy UI | 2 | 1 | Q4 | Decline / backlog |

## Common Mistakes

- Treating all incoming requests as urgent (everything lands in Q1)
- Never scheduling Q2 → perpetual firefighting
- Confusing **effort** with **importance** (hard ≠ important)
- Using the matrix for binary technical choices (use **decision-matrix**)

## Complementary Skills

- **impact-effort** — ROI within a quadrant
- **confidence-speed-quality** — how fast to execute Q1 items
- **cynefin-framework** — when urgency comes from unclear problem type
