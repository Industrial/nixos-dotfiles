---
name: connection-circles
description: Map causal links between system variables with polarity (+/-) and trace closed loops to find reinforcing and balancing feedback. Use as a stepping stone to causal loop diagrams and leverage-point analysis.
---

# Connection Circles — System Mapping

## Goal

Make **causal structure explicit** by linking variables in a circle layout, annotating polarity, and identifying **feedback loops** that explain persistence, growth, or resistance.

Precursor to full **Causal Loop Diagrams (CLDs)** in systems thinking.

## When to Use

- Multiple factors interact; linear cause-effect is insufficient
- "Why does this keep happening?" despite fixes
- Before designing interventions (find leverage points)
- Group sense-making workshops

## When NOT to Use

- Single direct cause with evidence
- Need quantitative simulation (CLD → stock-flow model)
- Fewer than 3 variables in play

## Core Notation

**Variable:** noun phrase representing something that increases/decreases (not an event — "Morale" not "Meeting held").

**Causal link (→):** A influences B.

**Polarity on link:**
- **+ (same):** Increase in A → increase in B (or decrease → decrease)
- **− (opposite):** Increase in A → decrease in B

**Feedback loop:** Closed path returning to starting variable.

**Loop type (count − links in loop):**
- **Even number of − links (including zero)** → **Reinforcing (R)** — amplifies change
- **Odd number of − links** → **Balancing (B)** — counteracts change, seeks goal

## Workflow for AI Agents

### Step 1 — List 5–12 key variables

From stakeholders, data, and **iceberg-model** structures. Use nouns.

### Step 2 — Arrange in a circle (conceptual)

Physical layout doesn't affect logic; circle encourages closing loops.

### Step 3 — Draw justified causal links

For each proposed link, state:
- Mechanism (how does A affect B?)
- Polarity (+/−)
- Time delay if significant (note "delay" on link)

Skip weak or speculative links; mark uncertain links dashed.

### Step 4 — Trace all closed loops

Start at each variable; follow arrows; record loops.

### Step 5 — Classify loops R or B

Count − signs in loop. Label R or B.

### Step 6 — Narrate loop stories

For each major loop, write 2–3 sentences: "As X rises, Y rises (+), which increases X (+) — reinforcing growth."

### Step 7 — Identify leverage points

Ask:
- Where can we weaken a vicious R loop?
- Where can we strengthen a virtuous R loop?
- What balancing loop is stuck? (goal wrong, delay too long)

Donella Meadows' leverage hierarchy: mental models > structure > parameters.

## Output Template

```markdown
## Connection Circles — [system]

### Variables
A, B, C, D, E

### Links
- A →(+) B: more load increases errors
- B →(+) C: errors increase on-call stress
- C →(−) D: stress reduces code review quality
- D →(+) B: poor reviews increase errors

### Loops
**R1 (vicious):** B → C → D → B (1 negative → Balancing? count: B→C +, C→D −, D→B + = 1 − → **B**)

### Loop narratives
...

### Intervention ideas
- Break link D→B: mandatory review bot (structure)
```

## Software Engineering Example

**SaaS reliability spiral**

Variables: Incident rate, On-call load, Tech debt, Deploy frequency, Test coverage

Loop R (vicious): Incidents → less time → tech debt ↑ → incidents ↑

Intervention: Balancing loop via dedicated debt sprint (adds B loop targeting tech debt).

## Common Mistakes

- Variables that are events ("outage") vs stocks ("technical debt")
- Missing delays (cause appears simultaneous)
- Confusing correlation with causation — state mechanism
- Polarity errors on "less of A causes more of B" (− link)

## Polarity Quick Test

"If A goes up and nothing else changes, does B tend to go up (+) or down (−)?"

## Complementary Skills

- **reinforcing-feedback-loop** — deep dive on R loops
- **balancing-feedback-loop** — deep dive on B loops
- **iceberg-model** — variables from structure level
- **second-order-thinking** — narrative version of chains
