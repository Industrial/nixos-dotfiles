---
name: new-skill
description: >-
  Distill current-conversation knowledge into a new or extended skill under the skills tree. Planning/gap analysis first; author after approval.
---

# new-skill

# New Skill — distill conversation knowledge into `.cursor/skills/<group>/`

Mine the **current conversation** (and any files or URLs it references) for durable agent knowledge that is **not yet covered** by this repo's skills. Research each gap thoroughly, then **extend an existing skill** or **author a new grouped skill** under `skills/<category>/<skill-name>/`.

Planning and gap analysis are the primary deliverable until the user approves the skill plan (unless they explicitly asked for research + authoring in one pass).

---

## Skills (load before executing)

Review `.cursor/skills/` and load these before starting:

| Skill | Role in this command |
|-------|----------------------|
| `~/.cursor/skills-cursor/create-skill/SKILL.md` | SKILL.md structure, frontmatter, anti-patterns, verification checklist |
| `.cursor/skills/concise-planning/SKILL.md` | Atomic steps, acceptance criteria per deliverable |
| `.cursor/skills/continuous-improvement/SKILL.md` | When to fold lessons into existing docs vs new skills |

Do **not** create skills in `~/.cursor/skills-cursor/` — that directory is Cursor-internal.

---

## Mindset

- **Conversation is the source of truth** — Prefer what was actually struggled with, decided, or discovered over generic best practices the agent already knows.
- **Skills are for gaps, not encyclopedias** — Only capture knowledge the agent would otherwise lack or get wrong in *this* repo.
- **Group by domain, not by chat thread** — One conversation may yield zero, one, or several skills across different groups.
- **Extend before proliferate** — Add a section or `reference.md` to an existing skill when overlap is high; create a new skill only when triggers, scope, or audience differ.
- **Ground in evidence** — Cite repo paths, package names, ADRs, and official docs. Never invent APIs or folder layouts.
- **Reformulate with `/quality`** — Before presenting the gap analysis or final skills, restate the work at the highest rigor: precise terms, explicit decisions, no hand-waving.

---

## Phase 0 — Inventory existing skills (mandatory)

Map what already exists so you do not duplicate or fragment knowledge.

```bash
# List all skills (group = parent directory under .cursor/skills/)
find .cursor/skills -name 'SKILL.md' | sort
```

For each `SKILL.md`, read at minimum:

1. YAML `name` and `description` (discovery triggers)
2. Table of contents or first-level headings (scope)
3. Any `references/`, `rules/`, or linked files (depth)

Build a **coverage map**:

| Group | Skills | Primary triggers (from descriptions) |
|-------|--------|--------------------------------------|
| `effect.ts-*` | … | … |
| `logto/` | … | … |
| `nextjs/` | … | … |
| … | … | … |

Use **roam** or **lean-ctx** when the conversation touched code: `roam context <symbol>`, `ctx_read mode=map` on relevant feature folders.

---

## Phase 1 — Extract knowledge from the conversation

Scan the full thread (user messages, assistant reasoning, tool output, errors fixed, URLs shared) and extract **candidate knowledge units**:

| Unit | Example |
|------|---------|
| **Domain** | Logto org roles, Temporal child workflows, Drizzle migrations |
| **Repo-specific convention** | `devenv shell --`, `@idclear/effect-react` layer split |
| **Workflow** | How to debug e2e serial failures, how to claim Maestro tasks |
| **Decision / ADR** | Why mutations go through API routes, not server actions |
| **Pitfall** | Mistake made and corrected in-thread |
| **Tooling** | MCP server usage patterns for this repo |

For each unit, record:

- **Trigger phrases** — What the user would say to need this again
- **Evidence** — Message quotes, file paths, command output
- **Staleness risk** — Stable convention vs version-sensitive API

Discard units that are:

- One-off task status ("fix line 42") with no reusable pattern
- Already fully covered by an existing skill (same triggers + same repo facts)
- Generic programming knowledge with no repo or stack specificity

---

## Phase 2 — Gap analysis

Classify each surviving unit:

| Status | Action |
|--------|--------|
| **Covered** | Note which skill; optionally add a cross-link in that skill's "See also" |
| **Partial** | **Extend** existing skill — new section, checklist, or `reference.md` |
| **Missing** | **New skill** — needs its own `name`, `description`, and trigger set |
| **Missing group** | **New group** `<group>/` when ≥2 related skills share a domain not represented in the tree (e.g. `webhook/`, `yugabyte/`) |

**Grouping rules**

- Place under an existing group when the skill is a specialization (`logto/`, `temporal/`, `react/`, `docker/`, `design/`, `playwright/`, `nextjs/`, `thinking/`, `linux/`)
- Keep repo-wide cross-cutting skills at `.cursor/skills/<skill-name>/` only when no group fits (e.g. `effect.ts-fundamentals`, `git-pushing`)
- Name skills: lowercase, hyphens, max 64 chars, specific not generic (`idclear-logto-monorepo` not `auth-helper`)
- Prefer **one skill per coherent workflow or subsystem**, not one skill per message

Output a **Skill Plan** (required before writing files):

```markdown
## Skill Plan

### Conversation summary
[2–4 sentences: what was done and what knowledge is worth preserving]

### Gaps

| # | Topic | Status | Target | Rationale |
|---|-------|--------|--------|-----------|
| 1 | … | extend / new / new group | `.cursor/skills/...` | … |

### Out of scope
- [Items intentionally not turned into skills]

### Research needed
- [ ] Topic A — sources: Context7, official docs, repo paths …
- [ ] Topic B — …
```

**Stop and ask the user to approve the Skill Plan** unless they said to proceed without confirmation.

---

## Phase 3 — Research (thorough, per gap)

For each gap marked extend or new, research **before** writing prose.

### Research stack (use in parallel)

| Source | When |
|--------|------|
| **This repo** | `ctx_read`, `roam preflight`, `roam context`, read canonical implementations |
| **Context7 MCP** | `resolve-library-id` → `query-docs` for framework/library APIs |
| **searxng MCP** | Official docs, release notes, authoritative blog posts when Context7 is thin |
| **Conversation artifacts** | Commands run, diffs, error messages — extract exact flags and paths |
| **Existing skills** | Avoid contradicting; align terminology with sibling skills in the same group |

### Research outputs (per topic)

Capture in notes (not necessarily committed):

1. **Facts** — APIs, config keys, file paths, commands (with `devenv shell --` if applicable)
2. **Invariants** — Must / must-not rules grounded in this codebase
3. **Examples** — Minimal correct snippets from the repo or docs
4. **Failure modes** — Errors seen in conversation + fixes
5. **Version anchors** — Package versions or doc dates when behavior is version-sensitive

**Quality bar:** You should be able to answer "why this way in *this* repo?" for every non-obvious bullet. If you cannot, research more or mark as open question in the Skill Plan.

---

## Phase 4 — Author or extend skills

Follow `create-skill` conventions. Default layout:

```
skills/<category>/<skill-name>/
├── SKILL.md              # Required — ≤500 lines, essential workflow + links
├── reference.md          # Optional — API tables, long examples
├── resources/            # Optional — playbooks (match sibling skills)
└── rules/                # Optional — lint-style rule files (match react/busirocket pattern)
```

### New `SKILL.md` frontmatter

```yaml
---
name: skill-name
description: >-
  Third-person WHAT + WHEN. Include trigger terms for discovery.
  Use when [scenarios]. Prefer over [obsolete/conflicting skill] in this repo.
disable-model-invocation: true
---
```

Omit `disable-model-invocation` only when the skill should auto-load from ambient context (rare; match `react-best-practices` / `composition-patterns` only if truly universal).

Optional metadata (match repo conventions when relevant):

```yaml
category: framework | tooling | process | design
displayName: Human-readable title
color: purple
```

### Body structure (template)

```markdown
# Title

## Purpose
[When to use / when NOT to use — link prerequisites]

## Layout (repo-specific)
[Tables of paths, modules, env vars — only for this monorepo]

## Core rules
[Numbered invariants the agent must follow]

## Workflow
[Step-by-step checklist the agent can copy]

## Examples
[Correct vs incorrect — short, from research]

## Failure modes
[Symptoms → cause → fix]

## See also
- `.cursor/skills/<group>/<other>/SKILL.md`
- Official: [link]
```

### Extending an existing skill

- Add content under the most specific heading; do not duplicate existing sections
- If addition > ~80 lines, move detail to `reference.md` and link one level deep from `SKILL.md`
- Update the `description` frontmatter if new trigger terms are needed
- Add "See also" cross-links bidirectionally when two skills are complements

### Repo alignment checks

- Shell commands wrapped with `devenv shell --` when this repo uses devenv
- Effect.ts skills: Layer-based testing, no `vi.mock` for Effect services
- Auth: prefer `logto/` skills over generic `clerk-nextjs-skills` / `authjs-skills` for this repo
- Task tracking: reference Maestro (`maestro` / `.maestro/`), not markdown TODO lists
- Navigation: mention `roam` commands where blast-radius matters

---

## Phase 5 — Verification

Before declaring done, run this checklist for **each** touched skill:

### Content quality
- [ ] `description` is third person, specific, includes WHAT + WHEN + trigger terms
- [ ] `SKILL.md` ≤ 500 lines; overflow in `reference.md` or `resources/`
- [ ] No time-bombed advice ("before August 2025…"); use "Current" / "Legacy" sections instead
- [ ] Terminology consistent with sibling skills in the same group
- [ ] Every repo path mentioned was verified to exist
- [ ] No duplication of an existing skill's core workflow (merge or cross-link instead)

### Structure
- [ ] File references one level deep from `SKILL.md`
- [ ] `name` matches directory and is unique under `.cursor/skills/`
- [ ] Group folder name is lowercase, domain-clear

### Discovery
- [ ] `/skills` command would plausibly pick this skill for the conversation triggers
- [ ] Related skills updated with "See also" if overlap exists

### Deliverable to user

```markdown
## New skills report

### Created
- `.cursor/skills/<group>/<name>/` — [one-line purpose]

### Extended
- `.cursor/skills/.../SKILL.md` — [what was added]

### Skipped (already covered)
- [topic] → [existing skill]

### Suggested follow-ups
- [ ] Commit skills in a dedicated commit
- [ ] Run a task using `/skills` to validate discovery
```

---

## Anti-patterns

| Do not | Do instead |
|--------|------------|
| Create a skill for every library mentioned once | Merge into group skill or extend `nextjs/` / `react/` parent |
| Copy full vendor docs into `SKILL.md` | Distill invariants + link to Context7 / official docs |
| Create `helper`, `utils`, `misc` skills | Name by workflow or subsystem |
| Write skills in `~/.cursor/skills-cursor/` | Project skills in `.cursor/skills/` only |
| Contradict `AGENTS.md`, `CLAUDE.md`, or Maestro docs | Align or add "See also" to harness docs |
| Paraphrase user verbatim requirements into skills | Use their exact wording for contractual/copy requirements only |
| Bake session-specific numbers into reusable docs (e.g. "5-step", "30/30 passing", "after all six edits"). The count is true once and wrong for the next reader — and forces a future editor to either accept a stale literal or audit git history. | Add new requirements as sub-bullets or "Additionally…" paragraphs. Counts that genuinely need to stay numeric belong in code or lint, not prose. |
| Name the specific tool that triggered the lesson when adding a pitfall to a generic skill (e.g. "when you use `mcp_lean_ctx_ctx_patch`" inside a guide about authoring Nix files). The tool is one of many possible causes; the skill will outlive the tool. | State the underlying mechanism (treefmt rewrites `...}:` to `... }\\n}: let`). Tool names belong in commit messages and changelogs, not in skills that should survive the next tool migration. |
| Treat a skill as a journal — pinning a specific mission id, ticket key, "first claim" task, "this session" wording, a workstream codename, or a "Rust migration missions" qualifier inside an otherwise generic guide. | Skills are guides that outlive any one session. Pin live state in `.maestro/`, `maestro status`, commit messages, or a `references/<date>.md`; the skill body stays generic. Concrete tells and the audit procedure live in `references/skill-vs-history-log.md`. |

## Skill vs history log — when an edit crosses the line

Before committing any change to a `SKILL.md`, run the smell test in `references/skill-vs-history-log.md`. If any tell fires, the change either does not belong in the skill body or it belongs in a `references/<date>.md` snapshot instead. Two rules carry the principle:

- **Skills outlive any one session.** A fact true only because of a specific mission, PR, branch, workstream, or tool version is not a skill fact — it is a session fact. Capture it where the session is recorded (Maestro sidecar, PR description, commit message, history file). The skill stays generic.
- **Audit, don't decorate.** When asked to "check all skills for X", read each first-party skill end-to-end and report findings before editing. Do not patch as you go. The audit and the fix are separate steps so the user can redirect scope.

The `~/.hermes/memories` store holds user identity and environment facts; skills hold reusable procedure. A session-specific number, ticket id, or workstream qualifier is neither — it is **state**, and state belongs in the project tree, not in a guide.

---

## Quick invocation summary

1. Inventory `.cursor/skills/**/SKILL.md`
2. Extract knowledge units from the conversation
3. Gap analysis → **Skill Plan** → user approval
4. Research each gap (repo + Context7 + searxng)
5. Extend or create grouped skills
6. Verify and report

