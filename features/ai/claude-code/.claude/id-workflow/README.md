# ID Workflow Pack

Mode-gated Industrial Delivery pipeline for Cursor agents.

## Why

Day-to-day stacking of `/quality` `/skills` `/agent` `/debate` `/plan-hierarchically` is optional and leaky. ID Workflow forces ORIENT → RESEARCH → PLAN → EXECUTE → REVIEW → SHIP with write bans, human gates, and Maestro as the sole tracker.

## Usage

```
/id <task description>
```

Mode jumps: `/id-orient` `/id-research` `/id-plan` `/id-execute` `/id-review` `/id-ship`.

Slash entrypoints live as flat files under `.cursor/commands/id*.md` (Cursor does not discover nested command folders). This directory is the **canonical pack** those entrypoints load.

## Layout

| Path | Role |
|------|------|
| [PROTOCOL.md](PROTOCOL.md) | Hard rails + mode machine |
| [lanes.md](lanes.md) | tiny / normal / heavy skip rules |
| [modes/](modes/) | Per-mode playbooks |
| [checklists/](checklists/) | Exit criteria |
| [RESEARCH.md](RESEARCH.md) | External synthesis (RIPER, BMAD, SDD) |

## Integration

- PLAN → `/plan-hierarchically` (by reference)
- EXECUTE → Maestro claim→verify→ship + Definitively gates
- **Workspace policy:** no Maestro worktrees — `maestro task claim … --skip-worktree`; stay on the currently checked-out branch
- Agents → `.cursor/rules/agent-*.mdc`
- Skill → `.cursor/skills/id-workflow/SKILL.md`
