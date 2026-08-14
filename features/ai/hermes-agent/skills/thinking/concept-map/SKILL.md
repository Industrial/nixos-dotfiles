---
name: concept-map
description: Build hierarchical knowledge graphs with labeled linking phrases connecting concepts around a focus question. Use for domain learning, explaining systems, and surfacing knowledge gaps before design or documentation.
---

# Concept Mapping

## Goal

Externalize **structured knowledge** as a network of concepts and propositions so gaps, misconceptions, and cross-links become visible.

Developed by Joseph Novak (1970s) based on Ausubel's learning theory.

## When to Use

- Onboarding to a new domain or codebase
- Explaining architecture to stakeholders
- Pre-design discovery ("what do we know about X?")
- Identifying missing knowledge before committing to a plan

## When NOT to Use

- Causal dynamics over time (**connection-circles**)
- Prioritization decisions (**decision-matrix**, **impact-effort**)
- When a simple bullet list suffices

## Core Elements

| Element | Rule |
|---------|------|
| **Concept** | Noun or short noun phrase — one per node |
| **Linking phrase** | Verb phrase on edge — forms readable proposition |
| **Proposition** | [Concept A] —[linking phrase]→ [Concept B] must read as true sentence |
| **Focus question** | Scopes the map — every concept should relate to it |
| **Hierarchy** | General concepts at top; specific at bottom (when possible) |

**Cross-links:** edges across branches — often highest insight density.

## Workflow for AI Agents

### Step 1 — Formulate focus question

Must be specific:

Bad: "Tell me about auth"
Good: "How does user authentication flow from login to authorized API request in this system?"

### Step 2 — Brainstorm 15–25 concepts

From docs, code, interviews. One concept per sticky note (node).

### Step 3 — Rank by generality

Most general → top of hierarchy. Most specific → bottom.

### Step 4 — Build initial hierarchy

Connect with linking phrases. Read each proposition aloud — fix awkward links.

**Linking phrase examples:** "includes", "requires", "stores", "validates", "triggers", "is implemented by"

### Step 5 — Add cross-links

Ask: "What relates across branches?" Cross-links reveal integration points and hidden dependencies.

### Step 6 — Identify gaps

- Concepts with no links
- Propositions marked uncertain (?)
- Areas where focus question cannot be answered yet

### Step 7 — Iterate

Add concepts; split overloaded nodes; merge duplicates.

### Step 8 — Export

Structured format for reuse:

```json
{ "nodes": [...], "edges": [{ "from", "to", "label" }] }
```

## Quality Checklist

- [ ] Every edge has a linking phrase (not unlabeled arrows)
- [ ] Propositions read as valid sentences
- [ ] Focus question answerable from map
- [ ] At least 2 cross-links (for non-trivial domains)
- [ ] Gaps explicitly marked

## Output Template

```markdown
## Concept Map — [focus question]

### Focus question
...

### Hierarchy (top → bottom)
```
[User] --requests--> [Login API]
[Login API] --validates--> [Credentials]
[Credentials] --stored in--> [User Table]
[Login API] --issues--> [Session Token]
[Session Token] --checked by--> [Auth Middleware]
```

### Cross-links
- [Auth Middleware] --reads--> [User Table] (session lookup)

### Knowledge gaps
- Unknown: token refresh flow
- Uncertain: whether middleware runs on edge or origin
```

## Software Engineering Example

**Focus:** "What happens when a webhook is delivered?"

Concepts: WebhookService, Event queue, HMAC signature, Retry policy, Subscriber endpoint, Dead letter queue, Idempotency key

Cross-link: Idempotency key connects Event queue branch to Subscriber branch.

## Common Mistakes

- Sentences as nodes ("User clicks login") — use concepts ("Login action")
- Unlabeled arrows ("related to")
- Map too flat (no hierarchy)
- Map too large (>30 nodes) without sub-maps
- Treating map as causal loop diagram (use **connection-circles** for polarity)

## Complementary Skills

- **issue-trees** — hierarchical decomposition of problems (different purpose)
- **abstraction-laddering** — find right scope for focus question
- **connection-circles** — add dynamics after static knowledge map
- **productive-thinking-model** — Step 1 knowledge gathering
