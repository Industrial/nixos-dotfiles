# .cursor/commands to Maestro Mapping

## Command Files Examined
- `/home/tom/.dotfiles/.cursor/commands/new-skill.md` - Skill creation workflow
- `/home/tom/.dotfiles/.cursor/commands/plan-hierarchically.md` - Hierarchical planning for Maestro
- `/home/tom/.dotfiles/.cursor/commands/agent.md` - Agent selection
- `/home/tom/.dotfiles/.cursor/commands/quality.md` - IQ/formatting improvement
- `/home/tom/.dotfiles/.cursor/commands/pre-push.md` - Pre-push checks
- `/home/tom/.dotfiles/.cursor/commands/serena.md` - Serena tool usage
- `/home/tom/.dotfiles/.cursor/commands/skills.md` - Skills management
- `/home/tom/.dotfiles/.cursor/commands/debate.md` - Debate facilitation
- `/home/tom/.dotfiles/.cursor/commands/mcp-debug.md` - MCP debugging
- `/home/tom/.dotfiles/.cursor/commands/activate.md` - Agent activation

## Maestro Equivalents Examined
- `/home/tom/.dotfiles/.maestro/config.yaml` - Maestro configuration
- `/home/tom/.dotfiles/.maestro/tasks/NOW.md` - Current task state
- `/home/tom/.dotfiles/.maestro/tasks/tasks.jsonl` - Task database
- `/home/tom/.dotfiles/.maestro/missions/` - Mission definitions
- `/home/tom/.dotfiles/.maestro/specs/` - Specifications
- `/home/tom/.dotfiles/.maestro/plans/` - Plan documents

## Migration Pattern
Each .cursor command typically maps to:
1. A Maestro spec (`.maestro/specs/<command-name>.md`)
2. Either:
   - A Maestro mission (multi-step workflow) + decomposed tasks
   - A single Maestro task (simple action)

Example mapping for `new-skill.md`:
- Spec: `.maestro/specs/new-skill.md`
- Mission: `pln-new-skill-workflow` 
- Tasks: 
  - Inventory existing skills
  - Extract knowledge from conversation  
  - Gap analysis & skill plan
  - Research per gap
  - Author/extend skill
  - Verify skill

## Key Differences
- .cursor/commands: Standalone markdown files with procedures
- Maestro: Hierarchical system with specs → missions/tasks → execution overlays
- Maestro adds: Quality gates, verification, evidence tracking, parallel execution