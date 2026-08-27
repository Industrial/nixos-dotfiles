---
name: hard-choice
description: Classify decisions by impact and comparability to choose the right decision process — quick call, values-based choice, analysis, or deep deliberation. Use before investing analysis effort or when options feel incomparable.
---

# Hard Choice Model

## Goal

Match **decision process intensity** to **decision type** so the agent does not over-analyze lunch options or under-analyze irreversible commitments.

Based on Ruth Chang's work on hard choices and incommensurability; popularized as a 2×2 matrix (Untools, Shoukry).

## When to Use

- Unsure how much analysis a decision deserves
- Options feel "apples vs oranges"
- Stakeholder wants fast answer but stakes feel high
- Meta-decision before **decision-matrix** or **six-thinking-hats**

## When NOT to Use

- Decision type obvious (production incident → act)
- Matrix scoring already appropriate (comparable options, multi-criteria)

## The 2×2 Matrix

```
Impact
  ↑
  │  BIG CHOICE        │  HARD CHOICE
  │  (analyze deeply)  │  (values & identity)
  │────────────────────┼────────────────────
  │  NO-BRAINER        │  APPLES & ORANGES
  │  (decide fast)     │  (pick framing / values)
  └────────────────────┴──────────────────→ Comparability
         Easy                    Hard
```

| Type | Impact | Comparability | Process |
|------|--------|---------------|---------|
| **No-brainer** | Low | Easy | Decide immediately; don't overthink |
| **Apples & Oranges** | Low | Hard | Pick values/priorities; either fine |
| **Big Choice** | High | Easy | Analysis, experts, **decision-matrix** |
| **Hard Choice** | High | Hard | Deliberation, values, identity; no "correct" answer |

**Comparability:** Can options be ranked on shared dimensions with confidence?

**Impact:** Consequences of being wrong — reversible? Scope? Duration?

## Scoring Rubric for AI Agents

### Impact (1–5)

| Score | Definition |
|-------|------------|
| 1–2 | Low — easily reversible; affects few |
| 3 | Medium |
| 4–5 | High — costly to reverse; strategic or wide blast radius |

Threshold: Impact ≥ 4 → high impact row.

### Comparability (1–5)

| Score | Definition |
|-------|------------|
| 1–2 | Easy — shared metrics; clear winner possible |
| 3 | Mixed |
| 4–5 | Hard — different value dimensions; incommensurable goods |

Threshold: Comparability ≥ 4 → hard compare column.

## Workflow

### Step 1 — List options (2–5)

### Step 2 — Score impact and comparability

### Step 3 — Classify quadrant

### Step 4 — Apply quadrant playbook

**No-brainer:**
- Pick best obvious option in <5 minutes
- Document one-line rationale
- Move on

**Apples & Oranges:**
- Ask: "What matters more in this context?" (speed vs learning, etc.)
- Use **eisenhower-matrix** or gut check with **six-thinking-hats** Red
- Accept either choice may be fine
- Don't build weighted matrix

**Big Choice:**
- Full analysis: **decision-matrix**, **issue-trees**, expert input
- **inversion** pre-mortem
- Document decision record (ADR)

**Hard Choice:**
- Acknowledge no objectively best option
- Surface values: "What kind of team/org do we want to be?"
- Chang: hard choices are opportunities to **author identity** through commitment
- Use **six-thinking-hats** full sequence; involve stakeholders
- Commit fully after choosing (avoid regret loops)

### Step 5 — Record decision and review trigger

When to revisit: date, metric, or event.

## Output Template

```markdown
## Hard Choice Classification — [decision]

### Options
A, B

### Scores
- Impact: 5 (high) — irreversible architecture
- Comparability: 4 (hard) — performance vs simplicity

### Type: **Hard Choice**

### Recommended process
Values deliberation + ADR; not weighted matrix alone.

### Guiding values
1. Operability over raw performance
2. ...

### Decision
**Option B** — aligns with value 1 because ...

### Review trigger
Revisit if p99 latency > 500ms for 30 days
```

## Software Engineering Examples

| Decision | Type | Process |
|----------|------|---------|
| Lint rule for semicolons | No-brainer | Enable standard config |
| Tab vs spaces for new repo | Apples & Oranges | Pick team convention |
| Postgres vs DynamoDB for billing | Big Choice | Matrix + benchmarks |
| Monolith vs microservices for 4-person team | Hard Choice | Values + capacity reality |

## Common Mistakes

- Treating Hard Choice as Big Choice (false precision from matrix)
- Treating Big Choice as No-brainer (skipping analysis)
- Apples & Oranges paralysis (pick a value and commit)
- Hard Choice without stakeholder alignment (buy-in failure)

## Ruth Chang Insight

When options are incomparable, rationality doesn't pick a winner — **commitment creates reasons** after the choice. Agent should support explicit commitment, not endless comparison.

## Complementary Skills

- **decision-matrix** — Big Choice primary tool
- **six-thinking-hats** — Hard Choice deliberation
- **confidence-speed-quality** — No-brainer → speed; Hard Choice → quality
- **second-order-thinking** — Big/Hard choices need consequence chains
