---
name: issue-trees
description: Decompose problems MECE into hierarchical issue trees (diagnostic why-trees) or solution trees (how-trees) for systematic analysis. Use for complex scoping, root cause structuring, and consulting-style problem solving.
---

# Issue Tree Decomposition

## Goal

Break an ambiguous problem into **Mutually Exclusive, Collectively Exhaustive (MECE)** branches so analysis is complete, non-overlapping, and prioritizable.

Standard tool in management consulting (McKinsey, BCG); pairs with hypothesis-driven investigation.

## When to Use

- Problem too large to attack directly
- Scoping incidents, performance issues, revenue gaps
- Structuring research before deep dives
- Ensuring no angle is missed in reviews

## When NOT to Use

- Problem already decomposed and leaf nodes are actionable
- Single clear root cause with evidence
- Need combinatorial ideation (**zwicky-box**)

## Tree Types

| Type | Root question | Branch question | Example |
|------|---------------|-----------------|---------|
| **Problem / Issue tree** | Why does X happen? | Why? / What causes? | Why is churn up? |
| **Solution tree** | How do we achieve X? | How? | How do we reduce churn? |
| **Decision tree** | Which option? | Criteria branches | Which database? |

This skill focuses on **problem** and **solution** trees.

## MECE Rules

**Mutually Exclusive:** No item belongs to two sibling branches.
**Collectively Exhaustive:** Siblings cover all possibilities (no gaps).

| Valid split | Invalid split |
|-------------|---------------|
| By region: NA, EU, APAC | By region + by product (overlap) |
| Revenue = price × volume | Revenue + marketing (gap) |

**Test MECE:** Can every case fit exactly one branch? Is anything missing?

## Workflow for AI Agents

### Step 1 — State the problem at the root

One clear question. Not a solution disguised as problem.

Bad: "We need Kubernetes"
Good: "Why is deployment lead time > 2 days?"

### Step 2 — Choose decomposition axis

Pick **one** dimension per level:
- Process stage (design → build → test → deploy)
- Component (frontend, API, DB, infra)
- Category (people, process, technology)
- Mathematical (revenue = customers × ARPU × retention)

### Step 3 — Branch 2–5 siblings per node

Prefer 3–4. Avoid >5 (restructure).

### Step 4 — MECE-check each level

Before going deeper, verify siblings.

### Step 5 — Prioritize branches

Score leaves by:
- Likelihood of being root cause (problem tree)
- Impact if true
- Cost to investigate

Investigate high-priority leaves first (**hypothesis-driven**).

### Step 6 — Stop depth rule

Stop when leaf is:
- Testable with one investigation, or
- Actionable without further decomposition

Typically 3–4 levels deep.

### Step 7 — Synthesize upward

Confirmed leaf causes → implications for parent → revised root answer.

## Output Template

```markdown
## Issue Tree — [root question]

```
Root: Why is API latency high?
├── Request volume increased?
│   ├── Traffic spike (marketing) → investigate metrics
│   └── Bot traffic → check WAF logs
├── Per-request work increased?
│   ├── New N+1 queries → profile DB
│   └── External API slower → check p95 vendor
└── Infrastructure degraded?
    ├── CPU throttling → check K8s limits
    └── DB connection pool → check pool metrics
```

### Priority investigations
1. ...
```

## Software Engineering Example

**Root:** Why did CI become flaky?

```
CI flaky
├── Tests non-deterministic
│   ├── Time-dependent assertions
│   └── Shared state between tests
├── Environment drift
│   ├── Dependency version pin drift
│   └── Resource contention (parallel jobs)
└── Infrastructure
    ├── Runner disk full
    └── Network timeouts to registry
```

## Common Mistakes

- MECE violation: overlapping categories
- Too shallow (stop at "code quality")
- Too deep before prioritizing (analysis paralysis)
- Problem tree when solution tree is needed (or vice versa)
- Listing solutions in problem tree ("because we need Redis")

## Hypothesis Trees (variant)

Attach **hypothesis** to each branch: "If branch A is true, we expect signal S."
Prune branches when signal falsifies.

## Complementary Skills

- **first-principles** — validate branch assumptions
- **iceberg-model** — patterns/structures below issue tree leaves
- **decision-matrix** — choose among solution tree leaves
- **cynefin-framework** — Complex problems: shallow tree + probes on leaves
