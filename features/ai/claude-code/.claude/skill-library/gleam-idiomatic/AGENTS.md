# AGENTS notes for gleam-skill

This file is a reminder of things the AI agent (and future maintainers) tends to get wrong or forget when maintaining this Gleam agent skill.

It is **not** user-facing documentation. It exists to reduce repeated mistakes.

## 1. Skill structure

- **SKILL.md** — Main entry point with frontmatter (`name`, `description`). Keep it concise (~500 lines max). It should tell the agent which references to read (must-read vs load-when-needed).
- **references/** — One file per topic. Agent loads these on demand based on the task. Keep each reference focused and concise.
- **examples.md** — Do/don't pairs. Keep examples short (few lines each).

## 2. Description trigger terms

The `description` field in SKILL.md frontmatter is critical for skill discovery. Include key terms:

- Language name: "Gleam"
- File extension: ".gleam"
- Common libraries: "Wisp", "Lustre", "OTP", "JSON"
- Use cases: "backend", "frontend", "FFI"

## 3. References organization

- **Must-read** (always load): language-basics.md, style.md, stdlib.md
- **Load when needed**: ffi.md, otp.md, gleam-json.md, wisp.md, lustre.md, gleam-javascript.md, plinth.md

Do not duplicate content between references. Each reference should be self-contained but link to external docs (HexDocs, Gleam Tour) for full coverage.

## 4. Library reference files

Each library reference (otp.md, wisp.md, etc.) should include:

- **When to use** — brief context
- **Entrypoints** — main functions/modules (e.g. `lustre.simple`, `lustre.application`)
- **Link to HexDocs** — full API documentation

Keep library references concise; they're pointers, not full documentation.

## 5. Examples

- **examples.md** should show do/don't pairs for common mistakes.
- Focus on: config records, nested case, list.append, type imports, pipes vs fluent.
- Keep each example short (5–10 lines max).

This file should grow over time as more recurring pitfalls are discovered. The goal is to maintain consistency and reduce repeated mistakes when updating the skill.
