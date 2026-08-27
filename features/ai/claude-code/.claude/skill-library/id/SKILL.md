---
name: id
description: >
  Industrial Delivery orchestrator - start in ORIENT mode and auto-route by lane.
  Load and obey the ID workflow protocol. Declare every response with [ID:<MODE>] and lane:<tiny|normal|heavy>.
  Prefer this over stacking individual skills; still runs ORIENT steps internally.
tags: [orchestration, workflow, id, maestro]
---

# Industrial Delivery (ID) Orchestrator

## Purpose
Start in **ORIENT** mode and follow the ID workflow protocol. This is the main entry point for structured work using the Industrial Delivery system.

## How It Works

1. **Start in ORIENT**: Follow the ID workflow protocol:
   - Load and obey `.cursor/commands/id-workflow/PROTOCOL.md`
   - Follow `id-workflow/modes/orient.md` and `checklists/orient-exit.md`

2. **Declare every response**: Each response must start with:
   ```
   [ID:<MODE>]
   lane:<tiny|normal|heavy>
   ```
   Where MODE is one of: ORIENT, RESEARCH, PLAN, EXECUTE, REVIEW, SHIP
   These declarations are part of the agent's response text and should NOT be executed as shell commands.

3. **Auto-route by lane** (based on `id-workflow/lanes.md`):
   - `tiny` + clear → brief RESEARCH or EXECUTE (if files known)
   - `normal`/`heavy` → RESEARCH → PLAN (run plan-hierarchically body) → wait for approve → EXECUTE → REVIEW → SHIP

4. **Mode playbooks**: Use the mode-specific skills:
   - `id-workflow/modes/orient.md` → id-orient skill
   - `id-workflow/modes/research.md` → id-research skill
   - `id-workflow/modes/plan.md` → id-plan skill
   - `id-workflow/modes/execute.md` → id-execute skill
   - `id-workflow/modes/review.md` → id-review skill
   - `id-workflow/modes/ship.md` → id-ship skill

5. **Tracker constraint**: Do not invent a second tracker — Maestro is the only task tracker used.

## Usage
Instead of using `/id` slash command, activate the `id` skill which provides the same orchestration:

When the `id` skill is active (either manually loaded or contextually suggested):
1. Begin in ORIENT mode
2. Follow the orient skill guidelines
3. Declare your mode and lane in every response
4. Progress through the workflow as exit criteria are met
5. Use the mode-specific skills for guidance in each phase
6. Consider archiving significant work products (like plans) with timestamps in a history/ directory for future reference
7. In restricted environments where only memory/skill tools are allowed (e.g., when terminal/code_exec tools are denied), focus on skill updates, memory management, and planning rather than attempting to execute code or run commands
8. Remember that `[ID:<MODE>]` and `lane:<...>` declarations are part of the agent's response text and should NOT be executed as shell commands

## Key Difference from Slash Command
- **Slash command**: Manual invocation via `/id` in editor
- **Hermes skill**: Contextually activated based on conversation/task detection
- **Same outcome**: Both provide the ID workflow orchestration with mode gating and Maestro tracking
- **Same outcome**: Both provide the ID workflow orchestration with mode gating and Maestro tracking