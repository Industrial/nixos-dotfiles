---
name: architecture-doc-authoring
description: >
  Authoring normative architecture documentation (SERVICE.md-style ports &
  adapters / DI guides) and distilling project-specific docs into portable,
  project-agnostic guides. Use when documenting how a codebase wires services,
  dependency injection, composition roots, or hexagonal boundaries — or when
  converting an existing architecture doc into a generic reusable template.
  Markdown diagrams are mermaid by default, never ASCII art.
tags: [documentation, architecture, mermaid, ddd]
---

# Architecture Documentation Authoring

## Triggers

- "Document our DI / service / wiring architecture", "write an ARCHITECTURE.md / SERVICE.md"
- "Distill this project-specific doc into a generic guide for other projects"
- Reviewing whether an abstraction pattern (abstract classes, protocols, ports) is a good idea — deliver the verdict AS a normative doc

## Workflow

1. **Research the real wiring before writing a word.** Read the actual container/composition-root code, port declarations, and adapters. Count things (e.g. "17 Protocol ports, 2 ABCs") — verify every quantitative claim with a search/grep before it enters the doc. Docs citing wrong counts destroy their own authority.
2. **Verdict-first opening.** When the ask is a question ("is X a good idea?"), open with the answer and its amendment, then argue it. Do not bury the verdict in section 9.
3. **Write the project-specific doc**, anchored in the repo's own conventions (cite real files, real provider names).
4. **Distill a generic variant on request**: strip every project name, path, and domain term; rewrite code samples with neutral examples (DocumentStore/Clock); generalize tool choices into option tables (hand-rolled compose() vs declarative DI container). Then VERIFY zero leaks — grep the generic doc for the project's vocabulary; exit must be empty (see reference file for the recipe).

## Doc skeleton (proven shape)

1. When to reach for the pattern / when to skip it
2. The N load-bearing rules (everything else is elaboration)
3. Shape diagram (mermaid flowchart, layers as subgraphs)
4. Layer import-rule table (may import / must never import)
5. Port/interface declaration rules + mechanism decision table (Protocol vs ABC vs plain class)
6. Adapter implementation conventions
7. Composition root(s) — provider vocabulary table, selector idiom, cost-of-adapter-N+1 trace
8. Testing the seams (override-not-patch, bare-class fakes, tiers)
9. **When NOT to abstract** — mandatory anti-pattern guardrails section
10. Checklist / quick reference; optional deviations-debt table naming exact files

## Style rules (user preference — non-negotiable)

- **Mermaid diagrams by default. Never hand-drawn ASCII box diagrams.**
  - Layer/boundary maps: `flowchart LR` with one subgraph per layer, dotted edges for "depends on Ports", thick `==>` edges for wiring.
  - Request/wiring traces: `sequenceDiagram` with `autonumber`.
  - Keep syntax conservative: quoted labels, `<br>` for breaks, HTML entities (`&lt;bc&gt;`) for angle brackets in labels — renders on GitHub/GitLab/CLI.
- Decision points become tables, not prose lists.
- Every rule gets a concrete code sample from the actual codebase (project doc) or a neutral equivalent (generic doc).

## Support files

- `templates/SERVICE_GENERIC.md` — portable ports/adapters/DI guide, verified zero project references; copy and adapt rather than rewriting from scratch.
- `references/markdown-diagram-editing.md` — mermaid conversion pitfalls, editor tool quirks, and the verification recipe (fence balance, block starts, leak grep).
