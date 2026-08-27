# Research synthesis

Condensed inputs for ID Workflow design. Not a runtime dependency.

| Source | Keep | Discard |
|--------|------|---------|
| [RIPER-5](https://github.com/johnpeterman72/CursorRIPER) | Explicit modes; write-ban outside Execute; mode declaration; human gate into Execute | Memory-bank dual tracker; theatrical violation language |
| [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) | Right-sized process; specialized personas; durable artifacts | Full BMAD install; parallel story system — **Maestro is tracker** |
| [cc-sdd](https://github.com/gotalab/claude-code-spec), [claude-workflow](https://github.com/sighup/claude-workflow), [rob-agent-workflow](https://github.com/robertraf/rob-agent-workflow) | Spec-before-code; per-task TDD; independent review; parallel dispatch | Separate `.specs/` trees duplicating Maestro |
| Cursor platform | Flat `.cursor/commands/*.md` for slash discovery; nested packs as referenced docs | Nested folders as sole slash surface ([forum](https://forum.cursor.com/t/commands-from-nested-folders-are-not-getting-read/146822)) |

**Locked decisions:** pack at `commands/id-workflow/` + flat `/id*`; Maestro-only tracking; 6 modes; 4 agent personas.
