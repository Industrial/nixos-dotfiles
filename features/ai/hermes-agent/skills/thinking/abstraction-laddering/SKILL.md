---
name: abstraction-laddering
description: Reframe problems by climbing up (why) for broader context or down (how) for concrete subproblems. Use when the stated problem is too narrow, too vague, or solving the wrong thing.
---

# Abstraction Laddering

## Goal

Escape fixation on a single problem framing by moving **up the ladder** (more abstract, strategic) or **down** (more concrete, actionable) until the right level for intervention is found.

Also called **Why–How Laddering** (LUMA Institute, design thinking).

## When to Use

- Stakeholder asks for a specific solution before problem is understood
- Team disagrees whether problem is strategic or tactical
- Feature request that may be a symptom
- Early discovery / problem framing

## When NOT to Use

- Problem already validated with users and metrics
- Execution phase with frozen scope
- Need combinatorial options (**zwicky-box**)

## The Ladder

```
        ↑ WHY (more abstract)
        │
   "Grow revenue"
        │
   "Increase retention"     ← current framing
        │
   "Fix onboarding step 3"
        │
        ↓ HOW (more concrete)
```

- **Why?** → parent problem (broader goal)
- **How?** → child problem (implementation / subgoal)

Same statement sits between its **why** (above) and **how** (below).

## Workflow for AI Agents

### Step 1 — Write the current problem statement

One sentence. This is the starting rung.

### Step 2 — Ladder up (2–4 why levels)

Ask: "Why does this matter? What higher goal does it serve?"

Stop when you reach:
- Organizational mission / user outcome, or
- Statement too abstract to act on

Record each level.

### Step 3 — Ladder down (2–4 how levels)

From the **original** or **reframed** statement, ask: "How might we address this? What subproblems must be solved?"

Stop when leaves are actionable tasks.

### Step 4 — Select the best rung for intervention

| Situation | Intervene at |
|-----------|--------------|
| Wrong problem entirely | Higher rung (reframe) |
| Right goal, wrong scope | Middle rung |
| Clear goal, need tasks | Lower rung |

### Step 5 — Document reframes

List 2–3 alternative framings discovered upstairs/downstairs.

### Step 6 — Validate with stakeholder

"Is the real problem X or Y?"

## Question Bank

**Why (up):**
- Why is this a problem now?
- Who benefits if we solve it?
- What happens if we do nothing?
- Why was this framed as [specific solution]?

**How (down):**
- What would solving this look like concretely?
- What are the smallest testable steps?
- What subsystems are involved?
- What must be true before this can work?

## Output Template

```markdown
## Abstraction Ladder — [topic]

### Starting statement
"Improve onboarding step 3"

### Ladder
| Level | Statement |
|-------|-----------|
| Why+2 | Increase product-led growth |
| Why+1 | Reduce signup-to-activation drop-off |
| **Current** | Improve onboarding step 3 |
| How+1 | Simplify form fields on step 3 |
| How+2 | Add progressive disclosure component |

### Recommended framing
Focus at Why+1 — step 3 may not be the drop-off point (verify analytics).

### Alternative framings
- ...
```

## Software Engineering Example

**Request:** "Add Redis caching"

| Level | Reframe |
|-------|---------|
| Why+1 | Reduce API latency for dashboard |
| Why+2 | Improve perceived performance for power users |
| How+1 | Cache `/api/summary` responses |
| How+2 | TTL 60s; invalidate on write |

Laddering up reveals **latency** may need profiling first — Redis might not be the right how.

## Common Mistakes

- Only laddering up (analysis paralysis) or only down (tactical tunnel vision)
- Treating reframes as facts without validation
- Skipping stakeholder check on reframed problem
- Each how-branch needs separate ladder (don't mix branches)

## Complementary Skills

- **first-principles** — challenge assumptions at each rung
- **issue-trees** — decompose how-level into MECE branches
- **productive-thinking-model** — Step 1 "What's going on?"
- **iceberg-model** — why-ladder approaches mental models
