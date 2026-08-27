---
name: agent-role-selection
description: >-
  Pick the right agent role for the task. Use when deciding who does what on a multi-step delivery (maps to ID modes).
---

# agent-role-selection

From `.cursor/rules/agent-*.mdc`:

| Role | Rule | Typical ID mode |
|------|------|-----------------|
| Researcher | `agent-researcher.mdc` | ORIENT / RESEARCH |
| Architect | `agent-architect.mdc` | PLAN |
| Implementer | `agent-implementer.mdc` | EXECUTE |
| Reviewer | `agent-reviewer.mdc` | REVIEW / SHIP |

State which rule you load. Prefer the `id-workflow` skill so mode + agent stay aligned.
