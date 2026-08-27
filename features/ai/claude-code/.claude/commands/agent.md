Pick the right agent for the task from `.cursor/rules/agent-*.mdc`:

| Role | Rule | Typical ID mode |
|------|------|-----------------|
| Researcher | `agent-researcher.mdc` | ORIENT / RESEARCH |
| Architect | `agent-architect.mdc` | PLAN |
| Implementer | `agent-implementer.mdc` | EXECUTE |
| Reviewer | `agent-reviewer.mdc` | REVIEW / SHIP |

State which rule you load. Prefer `/id` so mode + agent stay aligned.
