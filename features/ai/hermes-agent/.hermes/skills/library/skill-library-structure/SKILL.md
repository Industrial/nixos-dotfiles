---
name: skill-library-structure
description: |
  Class‑level convention for organizing Hermes skills within the project.
  Every skill that belongs to the shared library must follow this pattern:
  - reside under `features/ai/hermes-agent/plugins/<plugin>/`
  - contain a `SKILL.md` with rich documentation
  - include a `references/` directory for session‑specific detail, research excerpts, API specs, and external citations
  - include a `templates/` directory for starter files (configs, scaffolds)
  - include a `scripts/` directory for re‑runnable actions (verification scripts, fixtures)
  - support files are linked from `SKILL.md` via a short pointer line
  - skill names must be class‑level (e.g. `prism-analysis`, `brainstorm-code`) and must not be tied to a specific PR, error string, or fleeting session artifact
  - when a skill is superseded, it must be `absorbed_into` another umbrella skill rather than simply deleted
  - updates to the convention are stored as a separate skill (e.g. `skill-library-structure`) so the rule set can evolve independently
---

# Library‑wide Conventions

## Directory Layout

Each skill directory **MUST** contain the following items:

- `SKILL.md` – full skill documentation (required)
- `references/` – session‑specific notes, research excerpts, API specs, external quotes
- `templates/` – copy‑and‑modify starter files (configs, scaffolds)
- `scripts/` – deterministic scripts the skill can invoke (verification scripts, fixtures)

The `~/.hermes/skills/` tree (symlinked from `features/ai/hermes-agent/.hermes/skills/`) is the source of truth for Hermes SKILL.md files.

NOTE: `features/ai/hermes-agent/plugins/` is where Nix-built Python plugin *packages* live (each with a `package.nix`, `pyproject.toml`, and `register(ctx)` entry point). These are distinct from SKILL.md skill files. See the `hermes-plugin-authoring` skill for the plugin package pattern.

## Skill Naming

- Use **class‑level** names that describe a category of work, not a specific issue, PR number, or fleeting error.
- Examples of valid names: `brainstorm-code`, `prism-analysis`, `superpowers-integration`.
- Invalid names: `fix-#1234`, `debug-auth-error`, `PR-5678`, `audit-today`.

## Skill Content

- `SKILL.md` must start with YAML front‑matter containing at least `name:` and `description:`.
- The body should be concise, focusing on the **class** of task the skill handles.
- Include a “Pitfalls” or “Gotchas” subsection for known traps.
- Reference any support files with a one‑line pointer, e.g.:

  ```
  See also: references/intro-to-prism.md
  ```

## What to Version Control

When setting up skill directories or Hermes configuration in a repository:
- **Version control these specific paths**:
  - `.hermes/config.yaml`
  - `.hermes/skills/` (your custom skills)
  - `.hermes/plugins/` (your custom plugins)
  - `.hermes/memories/` (if you want to persist memories across clones)
  - `.hermes/cron/` (if you want to share cron jobs)
- **Do NOT version control**: Runtime/cache data including:
  - `.hermes/sessions/`, `.hermes/logs/`, `.hermes/cache/`
  - `.hermes/image_cache/`, `.hermes/audio_cache/`, `.hermes/pastes/`
  - `*.db`, `*.db-shm`, `*.db-wal`, `*.log`
  - `.hermes_history`, `state.db*`, `verification_evidence.db`
  - Model caches: `models_dev_cache.json`, `provider_models_cache.json`, `ollama_cloud_models_cache.json`
  - Lock files: `*.lock`, `auth.lock`, `processes.json`
  - Temporary files: `interrupt_debug.log`, `.update_check`
  - Environment secrets: `.env`
  - Sandboxes and pairing: `.hermes/sandboxes/`, `.hermes/pairing/`
  - Hooks: `.hermes/hooks/`
- The `~/.hermes/skills/` tree (symlinked from `features/ai/hermes-agent/.hermes/skills/`) should contain only skill definitions and user-created content
- See also: references/version-control-guidance.md

## Updating the Library

- To add a new convention, create a new umbrella skill (e.g. `skill-library-structure`) and document the change there.
- To modify an existing skill, use `skill_manage(action='patch')` and update its `SKILL.md` accordingly.
- When a skill becomes obsolete, set `absorbed_into=<umbrella>` before deletion.

## Context7 Integration

- All external documentation fetched via the Context7 MCP server should be cached in a memory entry and referenced from the skill’s `references/` directory.
- When a skill calls `mcp_context7_query_docs`, store the returned `content` in a memory slot named `ctx7_<libraryId>_<topic>` for reuse by other skills.

---

# Example Minimal Skill Layout

```
features/
└─ ai/
   └─ hermes-agent/
      └─ plugins/
         └─ brainstorm-code/
            ├─ package.nix
            ├─ pyproject.toml
            ├─ SKILL.md               ← rich documentation
            ├─ references/
            │   └─ brainstorm-conventions.md
            ├─ templates/
            │   └─ design-template.md
            └─ scripts/
                └─ verify-design.sh
```

Follow this template for every new skill to keep the library consistent and searchable.