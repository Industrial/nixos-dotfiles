---
name: maestro-command-migration
category: workflow
description: >-
  Migrate editor-specific slash command workflows (e.g., .cursor/commands) to Maestro missions and tasks.
  Use when replacing ad-hoc command files with Maestro's hierarchical planning, tracking, and verification.
disable-model-invocation: true
---

# Migrating Editor Slash Commands to Maestro

## Purpose
Replace editor-specific command files (like `.cursor/commands/*.md`) with Maestro missions/tasks to gain centralized tracking, quality gates, parallel execution, and cross-session continuity.

## Core Rules
- Each `.cursor/commands/<name>.md` becomes a Maestro mission (for multi-step workflows) or a single task (for simple actions).
- Mission specs live under `.maestro/specs/<name>.md`.
- Tasks are derived from mission decomposition or created directly from specs.
- Use Maestro CLI (`devenv shell -- maestro ...`) for all operations; avoid direct file edits to command files.
- Every mission/task must include acceptance criteria, file changes, and verification steps.

## Workflow
1. **Inventory**: List existing `.cursor/commands/` files to migrate.
2. **Spec Authoring**: For each command, write a Maestro spec describing goal, scope, acceptance criteria.
3. **Mission Creation**: 
   - For workflows with multiple phases: `maestro mission from-spec .maestro/specs/<name>.md` → `pln-...`
   - Decompose into tasks: `maestro mission decompose ...`
   - For single-step commands: `maestro task from-spec .maestro/specs/<name>.md` → `tsk-...`
4. **Task Execution**: 
   - Claim task: `maestro task claim <id>`
   - Implement per spec.
   - Verify gates: `maestro task verify <id>`
   - Request verdict: `maestro verdict request --task <id>`
   - Ship: `maestro task ship <id>`
5. **Evidence**: Record each gate via `maestro evidence record`.
6. **Cleanup**: After migration, archive or remove the original `.cursor/commands/` file.

## Examples
### Before (Cursor command)
`.cursor/commands/new-skill.md` – a lengthy procedure for creating skills.

### After (Maestro)
- Spec: `.maestro/specs/new-skill.md`
- Mission: `pln-new-skill-workflow` with tasks for inventory, extraction, research, authoring, verification.
- Each task has its own spec and acceptance criteria.

## Failure Modes
| Symptom | Cause | Fix |
|---------|-------|-----|
| Command still works after migration | Old file not removed | Delete or archive `.cursor/commands/<name>.md` after verifying Maestro task exists |
| Missing acceptance criteria | Spec incomplete | Add measurable AC to spec before mission creation |
| Tasks stuck in claimed state | Verification not run | Run `maestro task verify` and `maestro verdict request` |

## See Also
- `.maestro/config.yaml` for quality gates
- `maestro-design` skill for spec authoring
- `maestro-task` skill for task execution loop