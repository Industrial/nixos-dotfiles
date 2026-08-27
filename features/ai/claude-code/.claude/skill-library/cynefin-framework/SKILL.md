---
name: cynefin-framework
description: Classify situations into Clear, Complicated, Complex, Chaotic, or Disorder domains and apply the matching sense-making response (best practice, expert analysis, safe-to-fail probes, stabilize-then-sense, or decompose). Use before choosing investigation vs experimentation vs execution strategy.
---

# Cynefin Framework — Situation Classification

## Goal

Match the **nature of the situation** to the **correct response mode** so the agent does not apply expert analysis to emergent problems, or experiment where best practices already exist.

Developed by Dave Snowden (1999). Pronounced *kuh-NEV-in*.

## When to Use

- Unclear whether to research, prototype, or execute
- Incidents with conflicting explanations
- New product areas with unknown user behavior
- Team disagrees on approach because they see different problem types

## When NOT to Use

- Simple prioritization among known options (**decision-matrix**, **impact-effort**)
- Personal task scheduling (**eisenhower-matrix**)
- After domain is already well-understood and stable

## The Five Domains

| Domain | Cause ↔ Effect | Knowledge | Response pattern |
|--------|----------------|-----------|------------------|
| **Clear** (Obvious) | Known, repeatable | Known knowns | **Sense → Categorize → Respond** (best practice) |
| **Complicated** | Knowable with analysis | Known unknowns | **Sense → Analyze → Respond** (expertise) |
| **Complex** | Emergent, retrospective only | Unknown unknowns | **Probe → Sense → Respond** (safe-to-fail experiments) |
| **Chaotic** | No stable patterns | Crisis | **Act → Sense → Respond** (stabilize first) |
| **Disorder** | Domain unclear | Confusion | Decompose; assign each part to a domain |

### Domain characteristics (detailed)

**Clear:** Right answer exists; categorize and apply SOP. Danger: complacency — Clear can become Chaotic if context shifts.

**Complicated:** Multiple valid answers; experts disagree legitimately. Good practice exists but requires analysis (architecture reviews, performance tuning).

**Complex:** Patterns emerge only after action. Cannot analyze your way to the answer — must run parallel safe-to-fail probes, amplify what works, dampen what fails.

**Chaotic:** No time for analysis. Act to reduce turbulence, establish command, then move toward Complex or Complicated.

**Disorder:** Default when uncertain. Break apart and classify pieces.

## Classification Questions

Answer honestly for the **specific decision at hand**:

1. **Do we know what causes the outcome?** Yes → Clear/Complicated. No → Complex/Chaotic.
2. **Is the situation under control?** No → likely Chaotic.
3. **Can experts agree on a good answer given enough time?** Yes → Complicated. No → Complex.
4. **Have we solved this exact thing before with a playbook?** Yes → Clear.
5. **Would an experiment teach us faster than a meeting?** Yes → Complex.

## Workflow for AI Agents

### Step 1 — State the decision or problem in one sentence

### Step 2 — Score each domain signal (0–2)

| Signal | Clear | Complicated | Complex | Chaotic |
|--------|-------|-------------|---------|---------|
| Repeatable precedent | 2 | 1 | 0 | 0 |
| Expert consensus possible | 2 | 2 | 0 | 0 |
| Requires experiment to learn | 0 | 0 | 2 | 1 |
| Active crisis / no patterns | 0 | 0 | 1 | 2 |

Highest column sum → primary domain. Tie → Complex (safer default than Clear).

### Step 3 — If Disorder, decompose

Split into sub-problems; classify each independently.

### Step 4 — Apply domain playbook

**Clear:**
- Find matching SOP, checklist, or documented pattern
- Execute; measure for deviation

**Complicated:**
- Convene/analysis: gather data, model options
- Consult domain expertise; compare trade-offs
- Choose good-enough answer; document rationale

**Complex:**
- Design 2–3 **safe-to-fail probes** (small, reversible, time-boxed)
- Run in parallel if possible
- Amplify successful patterns; retire failed ones
- Reassess domain as patterns emerge

**Chaotic:**
- Immediate stabilization action (rollback, isolate, communicate)
- Assign incident commander / single decision path
- Only after stability → sense and move to Complex

### Step 5 — Watch for domain drift

Document triggers that would reclassify (e.g., "if error rate > 5% for 10 min → Chaotic").

## Output Template

```markdown
## Cynefin Classification — [situation]

**Primary domain:** Complex
**Confidence:** medium — [why]

### Evidence
- ...

### Recommended response mode
Probe → Sense → Respond

### Proposed probes (if Complex)
1. [hypothesis] — [experiment] — [success signal] — [timebox]

### Domain drift triggers
- If X → reclassify to Chaotic
```

## Software Engineering Examples

| Situation | Domain | Response |
|-----------|--------|----------|
| Run database migration with documented runbook | Clear | Follow runbook |
| Choose ORM for new service | Complicated | Analyze requirements; expert review |
| Will users adopt new onboarding flow? | Complex | A/B probe with 5% traffic |
| Production down, unknown cause | Chaotic | Rollback / isolate; then investigate |
| "Fix performance" (vague) | Disorder | Split: API latency (Complicated) vs engagement (Complex) |

## Common Mistakes

- Applying Complicated analysis to Complex problems (analysis paralysis)
- Treating Chaotic as Complex (debating while system burns)
- Assuming Clear forever (context changes)
- One classification for entire program when sub-parts differ

## Complementary Skills

- **ooda-loop** — fast iteration in Complex/Chaotic
- **iceberg-model** — find structural drivers in Complex
- **first-principles** — when Complicated experts disagree on assumptions
