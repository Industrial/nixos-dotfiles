---
name: six-thinking-hats
description: Deliberately switch between six thinking modes (facts, emotions, risks, benefits, creativity, process) to produce balanced analysis without mixing modes. Use for high-stakes decisions, design reviews, and debiasing one-sided reasoning.
---

# Six Thinking Hats

## Goal

Prevent **mode-mixing** (arguing facts and feelings simultaneously) by wearing one hat at a time, producing traceable multi-perspective analysis.

Developed by Edward de Bono. "Parallel thinking" — everyone same hat, same time.

## When to Use

- High-stakes technical or product decisions
- Design/architecture reviews needing balance
- Team stuck in adversarial debate
- AI output feels one-sided (all optimism or all criticism)

## When NOT to Use

- Simple binary choice with clear data (**decision-matrix**)
- Time-critical incident (act first; hats after stabilize)
- User wants a single expert recommendation without exploration

## The Six Hats

| Hat | Mode | Focus | Language cues |
|-----|------|-------|---------------|
| **White** | Objective | Facts, data, gaps in knowledge | "We know…", "We need data on…" |
| **Red** | Intuitive | Gut feel, emotions, no justification required | "My instinct is…", "This feels risky" |
| **Black** | Critical | Risks, failure modes, why it won't work | "The danger is…", "This could fail because…" |
| **Yellow** | Constructive | Benefits, value, why it could work | "The upside is…", "This enables…" |
| **Green** | Creative | Alternatives, variations, "what if" | "Another option…", "We could also…" |
| **Blue** | Process | Agenda, sequencing, meta-control | "Next hat…", "We've covered…" |

**Rule:** Only one hat active at a time. No arguing across modes.

## Recommended Sequences

| Scenario | Sequence |
|----------|----------|
| **Exploration** (new problem) | Blue → White → Green → Yellow → Black → Red → Blue |
| **Evaluation** (existing proposal) | Blue → White → Yellow → Black → Green → Red → Blue |
| **Quick review** | White → Black → Yellow → Blue |
| **Risk audit** | White → Black → Green → Blue |

Spend ~2–4 minutes per hat for live sessions; agent can be more thorough in writing.

## Workflow for AI Agents

### Step 1 — Blue: Frame

- State the decision question
- List hats and sequence
- Define what "done" looks like

### Step 2 — White: Facts only

- Observable data, metrics, constraints
- Explicitly list **unknowns** (not guesses)
- No opinions, no solutions

### Step 3 — Red: Intuition (optional early)

- Surface discomfort, excitement, political concerns
- No defending feelings with logic yet

### Step 4 — Yellow then Black (evaluation) OR Green (exploration)

**Exploration path:** Green generates options → Yellow/Black evaluate each.

**Evaluation path:** Yellow benefits first (avoid premature negativity), then Black risks.

### Step 5 — Green: Fill gaps

- Alternatives that address Black concerns
- Combinations of partial solutions

### Step 6 — Blue: Synthesize

- Summary per hat
- Recommended next steps
- What data would change the recommendation

## Output Template

```markdown
## Six Hats Analysis — [decision]

### 🔵 Blue — Process
Question: ...
Sequence: White → Yellow → Black → Green → Blue

### ⬜ White — Facts
- Known: ...
- Unknown: ...

### 🟡 Yellow — Benefits
- ...

### ⬛ Black — Risks
- ...

### 🟢 Green — Alternatives
- ...

### 🔴 Red — Intuition
- ...

### 🔵 Blue — Synthesis
Recommendation: ...
Next: ...
```

## Software Engineering Example

**Decision:** Migrate monolith API to separate auth service.

| Hat | Output |
|-----|--------|
| White | 40 endpoints share session; 99.9% uptime SLA; team of 4 |
| Yellow | Independent auth deploys; clearer security boundary |
| Black | Distributed session failure; migration downtime; team bandwidth |
| Green | Auth module extraction first; strangler fig; BFF pattern |
| Red | Team anxious about on-call complexity |
| Blue | Recommend phased strangler; spike 1 week; revisit after metrics |

## Common Mistakes

- Mixing hats in one paragraph ("I feel [Red] but data shows [White]…")
- Skipping Yellow (pure criticism → demoralization)
- Skipping Black (optimism bias)
- Black hat as personal attack (critique ideas, not people)
- Green too early before White establishes facts

## Complementary Skills

- **ladder-of-inference** — validate White hat data vs interpretation
- **decision-matrix** — score Green alternatives
- **inversion** — strengthen Black hat
- **productive-thinking-model** — broader problem-solving container
