---
name: confidence-speed-quality
description: Calibrate whether to optimize for delivery speed or output quality based on confidence in problem importance and solution correctness. Use when choosing between quick iteration, thorough design, or balanced exploration.
---

# Confidence–Speed–Quality Tradeoff

## Goal

Avoid uniform quality (everything over-engineered) or uniform speed (everything fragile) by **explicitly calibrating tempo** to confidence level.

Related: "Move fast with confidence" — speed and quality are not always opposed when orientation is clear.

## When to Use

- Starting implementation with unclear requirements
- Choosing spike vs production-grade build
- Reviewing AI-generated code before shipping
- Sprint planning under uncertainty

## When NOT to Use

- Regulated/safety-critical paths (quality floor is non-negotiable)
- Clear-domain SOP with known correct implementation
- Post-incident fixes where root cause unverified (slow down)

## Core Model

Two confidence axes:

| Axis | Question |
|------|----------|
| **Problem confidence** | Are we solving the right problem? |
| **Solution confidence** | Will this approach work? |

Each axis: **low** | **medium** | **high**.

## Decision Matrix

| Problem ↓ / Solution → | Low | Medium | High |
|------------------------|-----|--------|------|
| **Low** | **Speed** — cheap probes; don't polish | **Speed** — learn problem first | **Balanced** — validate problem before scaling solution |
| **Medium** | **Speed** — spike both | **Balanced** — iterate | **Quality** — invest in solution |
| **High** | **Balanced** — confirm approach cheaply | **Quality** — build right | **Quality** — production grade |

### Strategy definitions

| Strategy | Behavior |
|----------|----------|
| **Speed** | MVP, spike, throwaway code, time-box; maximize learning per hour |
| **Balanced** | Core path solid; defer edges; tests on critical paths |
| **Quality** | Full design, edge cases, tests, docs, review; minimize rework |

## Workflow for AI Agents

### Step 1 — State the work unit

One deliverable: feature, fix, refactor, investigation.

### Step 2 — Score problem confidence (1–5)

| Score | Evidence |
|-------|----------|
| 1–2 | Assumption; no user/data validation |
| 3 | Some signal; not reproduced |
| 4–5 | Validated need; metrics; explicit requirement |

### Step 3 — Score solution confidence (1–5)

| Score | Evidence |
|-------|----------|
| 1–2 | Novel approach; no precedent in codebase |
| 3 | Pattern exists; minor unknowns |
| 4–5 | Proven pattern; done here before |

### Step 4 — Map to strategy

Use table above (treat 1–2 as Low, 3 as Medium, 4–5 as High).

### Step 5 — Define quality floor

Even in **Speed** mode:
- No secrets in code
- No data loss paths unguarded
- Reversible deploy preferred

Even in **Quality** mode:
- Time-box analysis; avoid gold-plating

### Step 6 — Set explicit exit criteria

What signal upgrades confidence? What triggers re-strategy?

Example: "If spike shows wrong API, revert to Speed on problem axis."

### Step 7 — Document choice in PR/plan

One line: "Speed mode — problem confidence low; spike only."

## Output Template

```markdown
## Confidence Calibration — [task]

| Axis | Score | Evidence |
|------|-------|----------|
| Problem | 2/5 | Stakeholder request only; no usage data |
| Solution | 4/5 | Standard retry pattern in codebase |

### Strategy: **Balanced** (confirm problem via feature flag to 5% users)

### Quality floor
- Feature flag; rollback documented
- Unit tests on retry logic only

### Upgrade triggers
- >10% adoption week 1 → Quality mode for edge cases
- Zero usage → stop; revisit problem
```

## Software Engineering Examples

| Task | P conf | S conf | Strategy |
|------|--------|--------|----------|
| Fix typo in README | 5 | 5 | Speed — just fix |
| New onboarding flow | 2 | 2 | Speed — prototype + user test |
| Payment webhook retry | 5 | 4 | Quality — money path |
| "Maybe optimize DB" | 2 | 3 | Speed — profile first |

## Iron Triangle Nuance

Classic: fast, good, cheap — pick two.

This model adds: **confidence enables speed without sacrificing quality** on the right parts. Low confidence + high quality = polished solution to wrong problem.

## Common Mistakes

- High quality on low problem confidence (waste)
- High speed on high-impact low solution confidence (production incidents)
- Never upgrading strategy after confidence increases
- Confusing manager urgency with problem confidence

## Complementary Skills

- **cynefin-framework** — Complex → usually Speed probes first
- **ooda-loop** — Speed mode iteration structure
- **hard-choice** — high impact lowers acceptable speed
- **inversion** — quality floor definition
