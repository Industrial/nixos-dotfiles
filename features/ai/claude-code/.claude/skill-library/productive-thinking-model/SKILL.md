---
name: productive-thinking-model
description: Six-step structured problem solving from situational understanding through success definition, catalytic questions, ideation, solution forging, and resource alignment. Use for open-ended problems needing creative yet executable outcomes.
---

# Productive Thinking Model (ThinkX)

## Goal

Move from messy situation to **actionable plan** through six disciplined steps — avoiding premature solutions and unfocused brainstorming.

Created by Tim Hurson (*Think Better*, 2007). Best when problem is defined enough to solve but solution path is unclear.

## When to Use

- Open-ended product or engineering problems
- Workshop facilitation structure
- After initial triage; before execution
- When team jumps to solutions too fast

## When NOT to Use

- Clear SOP exists (**cynefin-framework** Clear)
- Pure prioritization among known items (**impact-effort**)
- Single technical bug with obvious fix

## The Six Steps

```
1. What's going on?     → Understand situation (Target Future)
2. What's success?      → DRIVE criteria
3. What's the question? → Catalytic questions
4. Generate answers     → Brainstorm solutions
5. Forge the solution   → Select + refine
6. Align resources      → Execution plan
```

## Step 1 — What's going on?

**Purpose:** Rich situational awareness before solving.

**Guiding questions:**
- What is the problem exactly? (symptoms vs root)
- What is the impact? Who is affected? How much?
- What do we already know? What data exists?
- What do we not know? What must we learn?
- Who are stakeholders? What do they care about?
- What is the **Target Future** — vision when solved?

**Output:** Problem brief + Target Future statement (1 paragraph).

**Agent tip:** Use **iceberg-model** or **issue-trees** here if complexity is high.

## Step 2 — What's success?

**Purpose:** Define measurable success before generating solutions.

**DRIVE framework:**

| Letter | Question |
|--------|----------|
| **D**o | What must the solution **do**? (capabilities) |
| **R**estrictions | What must it **not** do? (constraints — use **inversion**) |
| **I**nvest | What resources can we invest? (time, people, money) |
| **V**alues | What values must it embody? (transparency, speed, …) |
| **E**ssential outcomes | What are the non-negotiable results? |

Cycle until success criteria are testable.

**Output:** DRIVE checklist with testable statements.

## Step 3 — What's the question?

**Purpose:** Convert situation + success into **catalytic questions** — questions that unlock progress when answered.

**Format:**
- "How might we …?"
- "How can we …?"
- "What would need to be true for …?"

Generate 10–15; cluster; pick 1–3 **most catalytic** (highest leverage if answered).

**Output:** Prioritized catalytic questions.

## Step 4 — Generate answers

**Purpose:** Divergent ideation — quantity over quality.

**Rules:**
- Brainstorm answers to catalytic questions
- No judgment during generation
- Build on ideas (YES AND)
- Target 20+ ideas before filtering

**Techniques:** **zwicky-box**, **six-thinking-hats** Green, analogies.

**Output:** Raw idea list tagged to catalytic questions.

## Step 5 — Forge the solution

**Purpose:** Converge — select and strengthen best option.

**Process:**
1. Score ideas against DRIVE criteria (**decision-matrix**)
2. Select top 1–2
3. **Forge:** What would make it better? Combine ideas? Address Black hat risks?
4. Define MVP vs full solution

**Output:** Selected solution with rationale + refinement notes.

## Step 6 — Align resources

**Purpose:** Make execution inevitable.

**Document:**
- Specific actions (verb-first, owner, deadline)
- Dependencies and blockers
- Success metrics from Step 2
- Communication plan

**Output:** Action plan ready for Maestro tasks or sprint tickets.

## Full Output Template

```markdown
# Productive Thinking — [topic]

## 1. What's going on?
### Problem
...
### Impact
...
### Target Future
...

## 2. What's success? (DRIVE)
- **Do:** ...
- **Restrictions:** ...
- **Invest:** ...
- **Values:** ...
- **Essential outcomes:** ...

## 3. Catalytic questions
1. How might we ...? (primary)
2. ...

## 4. Generated answers
- Idea 1 (Q1)
- ...

## 5. Forged solution
**Selected:** ...
**Rationale:** ...
**Enhancements:** ...

## 6. Resource alignment
| Action | Owner | Due |
|--------|-------|-----|
| ... | ... | ... |
```

## Software Engineering Example

**Problem:** Enterprise customer needs SSO; deals stalling.

| Step | Output |
|------|--------|
| 1 | 3 deals blocked; Target Future: SSO in 2 weeks, sales unblocked |
| 2 | Must support SAML; must not break existing OAuth users; 2 eng-weeks |
| 3 | "How might we add SAML without dual auth codepaths?" |
| 4 | IdP abstraction layer, Auth0 migration, Keycloak sidecar, … |
| 5 | Matrix → IdP abstraction + SAML provider adapter |
| 6 | Spike 3 days, implement adapter, docs for sales |

## Common Mistakes

- Skipping Step 1–2 (solution jumping)
- One catalytic question only when problem is multi-faceted
- Judging during Step 4
- Step 5 without DRIVE scoring (politics picks winner)
- Step 6 vague ("implement SSO") without owners/dates

## Complementary Skills

- **abstraction-laddering** — reframe in Step 1
- **decision-matrix** — Step 5
- **inversion** — Restrictions in Step 2
- **six-thinking-hats** — optional throughout
- **concise-planning** — convert Step 6 to implementation checklist
