# Thinking Skills — Agent Router

Structured thinking frameworks for AI agents. Each skill includes: when to use, step-by-step workflow, scoring rubrics, output templates, software examples, and common mistakes.

**Rule:** Pick **one primary** framework per decision. Combine sequentially (e.g., Cynefin → OODA → Decision Matrix), not in parallel.

## Quick Selection Guide

| Situation | Start here |
|-----------|------------|
| Too many tasks, limited time | **eisenhower-matrix** |
| Backlog / ROI sequencing | **impact-effort** |
| Wrong problem or vague ask | **abstraction-laddering** |
| Open-ended problem, need plan | **productive-thinking-model** |
| Complex problem structure | **issue-trees** |
| Don't know problem *type* | **cynefin-framework** |
| Fast-changing / uncertain | **ooda-loop** |
| Compare 3+ options on criteria | **decision-matrix** |
| Options feel incomparable | **hard-choice** |
| One-sided reasoning / bias | **ladder-of-inference** or **six-thinking-hats** |
| Need creative breadth | **zwicky-box** or **six-thinking-hats** (Green) |
| Challenge assumptions / innovate | **first-principles** |
| Avoid failure / pre-mortem | **inversion** |
| Long-term consequences | **second-order-thinking** |
| Recurring symptoms | **iceberg-model** |
| System dynamics / loops | **connection-circles** → **reinforcing-feedback-loop** / **balancing-feedback-loop** |
| Learn or explain a domain | **concept-map** |
| Spike vs production quality | **confidence-speed-quality** |

## By Category

### Prioritization & triage
- `eisenhower-matrix` — importance × urgency
- `impact-effort` — value × cost

### Problem framing & decomposition
- `abstraction-laddering` — why/how reframing
- `issue-trees` — MECE breakdown
- `productive-thinking-model` — 6-step end-to-end
- `iceberg-model` — events → mental models

### Decision making
- `decision-matrix` — weighted scoring
- `hard-choice` — how much process to apply
- `six-thinking-hats` — multi-perspective
- `confidence-speed-quality` — speed vs thoroughness

### Sense-making & context
- `cynefin-framework` — domain classification
- `concept-map` — knowledge structure
- `ladder-of-inference` — belief debugging

### Creativity & ideation
- `zwicky-box` — combinatorial morphological analysis
- `first-principles` — rebuild from constraints
- `inversion` — work backward from failure

### Dynamics & foresight
- `connection-circles` — causal map + loops
- `reinforcing-feedback-loop` — amplification (R)
- `balancing-feedback-loop` — stabilization (B)
- `second-order-thinking` — "and then what?"
- `ooda-loop` — observe-orient-decide-act cycles

## Common Pipelines

```
Discovery:  abstraction-laddering → concept-map → issue-trees
Strategy:   cynefin-framework → second-order-thinking → decision-matrix
Incident:   ooda-loop → iceberg-model → connection-circles
Ideation:   zwicky-box → decision-matrix → inversion (pre-mortem)
Delivery:   hard-choice → confidence-speed-quality → impact-effort
```

## Skill Files

All skills live in subdirectories with `SKILL.md`:

`abstraction-laddering`, `balancing-feedback-loop`, `confidence-speed-quality`, `concept-map`, `connection-circles`, `cynefin-framework`, `decision-matrix`, `eisenhower-matrix`, `first-principles`, `hard-choice`, `iceberg-model`, `impact-effort`, `inversion`, `issue-trees`, `ladder-of-inference`, `ooda-loop`, `productive-thinking-model`, `reinforcing-feedback-loop`, `second-order-thinking`, `six-thinking-hats`, `zwicky-box`
