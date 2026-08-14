# Library Conventions Overview

- Skills live under `features/ai/hermes-agent/plugins/<plugin>/`
- Required files: `SKILL.md`, `references/`, `templates/`, `scripts/`
- Skill names are class‒level (e.g. `brainstorm-code`), not tied to a specific issue
- `SKILL.md` must have YAML front‒matter (`name:`, `description:`)
- Support files are linked via one‒line pointer in `SKILL.md`
- Context7 docs cached in memory as `ctx7_<libraryId>_<topic>`
- When superseded, use `absorbed_into=<umbrella>` before deletion