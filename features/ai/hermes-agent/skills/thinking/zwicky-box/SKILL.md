---
name: zwicky-box
description: Generate solution space by listing independent problem dimensions and their values, then combining systematically (morphological analysis). Use for creative ideation, architecture variants, and exploring configuration spaces too large for brainstorming alone.
---

# Zwicky Box (Morphological Analysis)

## Goal

Escape local optima in brainstorming by **exhaustively exploring combinations** of independent attributes, then filtering with constraints.

Developed by Fritz Zwicky (1940s); also called **Morphological Box** or **General Morphological Analysis**.

## When to Use

- Many independent design dimensions (auth × storage × deployment × ...)
- Stuck with 2–3 obvious options
- Innovation workshops needing structured breadth
- Architecture option generation before **decision-matrix**

## When NOT to Use

- Single-dimension choice
- Problem structure unknown (use **abstraction-laddering** first)
- Full Cartesian product would be huge without pruning strategy

## Core Concepts

**Attribute (dimension):** Independent axis of variation (e.g., "session storage").
**Value:** Option on that axis (e.g., Redis, Postgres, JWT stateless).
**Configuration:** One value per attribute — a row in the combination space.
**Cross-consistency assessment (CCA):** Rule out incompatible pairs (e.g., "serverless" + "local filesystem state").

## Workflow for AI Agents

### Step 1 — Define the design problem

One sentence: what must the solution achieve?

### Step 2 — Identify 4–7 orthogonal attributes

Test orthogonality: changing attribute A should not force attribute B.

Good attributes: deployment model, data store, auth protocol, sync model.
Bad: "fast" and "performant" (duplicate).

### Step 3 — List 3–6 values per attribute

Include conventional, edge, and "null" options where valid.

### Step 4 — Build the Zwicky box (table)

| | Attr 1 | Attr 2 | Attr 3 |
|---|--------|--------|--------|
| v1 | ... | ... | ... |
| v2 | ... | ... | ... |

Full space size = product of value counts. Document size.

### Step 5 — Apply consistency constraints

List **forbidden combinations** and **required pairs**:

- IF serverless THEN no local disk state
- IF multi-region THEN eventual consistency or CRDT

Prune before or during enumeration.

### Step 6 — Generate configurations

**Full enumeration:** Cartesian product minus pruned (small boxes only).
**Sampled enumeration:** Random or Latin-hypercube sample for large spaces.
**Strategic enumeration:** Fix one attribute to current state; vary others.

Target 10–30 viable configurations for review.

### Step 7 — Score or cluster survivors

Group similar configs. Shortlist 3–5 for **decision-matrix** or prototype.

### Step 8 — Prototype highest-uncertainty dimension

If one attribute dominates risk, probe that axis first.

## Output Template

```markdown
## Zwicky Box — [problem]

### Attributes & values
1. **Auth:** OAuth2, SAML, magic-link, API-key
2. **Session:** JWT, server-side Redis, DB
3. **Deploy:** monolith, BFF+services, edge

### Space size
4 × 3 × 3 = 36 raw → 22 after CCA

### Consistency rules
- JWT + server-side Redis → invalid (pick one session model)
- ...

### Shortlist configurations
| # | Config | Notes |
|---|--------|-------|
| 1 | OAuth2 + Redis + BFF | Matches current team skills |
| 2 | magic-link + JWT + edge | Lowest ops; email deliverability risk |

### Recommended probe
Spike config #2 for 2 days — test email latency
```

## Software Engineering Example

**Problem:** Design webhook delivery system

| Attribute | Values |
|-----------|--------|
| Retry policy | exponential, fixed, none |
| Queue | SQS, Postgres, in-memory |
| Signing | HMAC-SHA256, Ed25519 |
| Delivery | HTTP only, HTTP+SSE fanout |

CCA: in-memory queue + multi-instance deploy → invalid.

## Common Mistakes

- Non-orthogonal attributes (double-counting)
- Generating thousands of combos without CCA
- Only listing safe/conventional values (defeats purpose)
- Skipping feasibility filter after generation
- Treating box output as final decision without scoring

## Complementary Skills

- **decision-matrix** — rank shortlisted configs
- **first-principles** — validate attribute list against constraints
- **inversion** — CCA from failure modes
- **six-thinking-hats** Green — populate unusual values
