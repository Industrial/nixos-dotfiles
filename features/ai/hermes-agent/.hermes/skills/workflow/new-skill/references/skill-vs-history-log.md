# Skill vs history log — smell test for SKILL.md edits

Skills outlive any one session. A `SKILL.md` is a **guide** the next session
loads cold, with no prior conversation. If a change to a skill only makes
sense because of *this* conversation, it is not a skill change — it is a
session artifact that belongs somewhere else.

This file is the audit checklist. Run it before committing any edit to a
`SKILL.md`. The companion rule lives in `../SKILL.md` under
**Anti-patterns → "Treat a skill as a journal…"**.

## Tells — the change is probably a history log

If **any** of the following appears in or near a `SKILL.md` edit, stop and
reclassify before committing:

| Tell | Example | Where it actually belongs |
|------|---------|---------------------------|
| Pinned mission id / plan id / task id | `pln-mpsu3xxd-h0s6jn`, `tsk-mpsu3z87-xy3w58` | `.maestro/missions/*.md`, `maestro status --json`, `.maestro/tasks/NOW.md` |
| "First claim:" / "current mission:" / "active workstream:" | "First claim: `tsk-…` (`domain-spec`)." | live state sources, not the skill |
| Workstream / app / repo-subdir name as a hardcoded noun | "Definitively code lives in `definitively/`." | repo README, history plan file, or the workstream's own docs |
| "Rust migration missions" / "for the elixir cutover" / "for the v0.106.1 port" qualifiers on a generic rule | "Every claim, verify, block, and handoff on Rust migration missions: run `/skills`…" | drop the qualifier; the rule is generic or it is not a rule |
| Specific commit SHA, PR number, or branch name in prose | "PR org/platform#5751 removes the single-stream fast-path…" | the post-mortem, history file, or PR description |
| A numeric count tied to one session | "5-step", "30/30 passing", "after all six edits" | code, lint, snapshot file, or sub-bullet ("Additionally…") |
| The specific tool that triggered a generic lesson | "when you use `mcp_lean_ctx_ctx_patch` inside a guide about authoring Nix files" | describe the underlying mechanism (the tool is one of many possible causes) |
| First-person session narration | "I tried X, then Y, then Z" | memory (if it is a stable fact about the user or environment) or the commit message (if it is a one-off) |
| Dates of the form `20YY-MM-DD` in body prose | "On 2026-08-19 the agent learned…" | the dated `history/<date>-<slug>.md` file, or just drop it |
| A "this skill currently does X" snapshot | "Active mission: FSM workflow definitively" | the source of truth it points at, not the skill |

## Tells — the change is probably a guide (proceed)

- Imperative voice ("Run `assay run nix/`", "Confirm `which assay` resolves")
- Numbered steps with stable semantics ("Steps 1–5 to add a program feature")
- "When to use / When NOT to use" sections
- Generic patterns reusable across sessions ("If a barrel-level count fails…")
- Quoted command lines, code snippets, table rows
- Tool-agnostic mechanism descriptions ("treefmt rewrites `...}:` to `... }: let`")

## Audit procedure

When the user asks to "check skills for X" or "audit skills":

1. **Inventory first-party skills.** The `workflow/`, `engineering/`, `git/`,
   `linux/`, `hermes-tool-routing-hooks/`, and `*idclear-*`-prefixed skills
   are first-party. Vendored upstream skills (Anthropic, Nous Research,
   Community) are out of scope unless the user names them.
2. **Read each skill end-to-end.** Do not grep-only — tells often hide in
   normal-looking paragraphs. `wc -l` first to size the work.
3. **Classify each finding.** For every tell, decide one of:
   - **Remove** — the content has no place in a guide.
   - **Move to a session artifact** — the content is real but lives
     elsewhere (`.maestro/`, history file, commit message).
   - **Generalize** — the content expresses a real rule, but the prose
     pins it to one workstream. Rewrite to drop the qualifier.
4. **Report findings first, then fix.** Show the user the list of
   history-log blocks before editing, so they can redirect scope. Do not
   patch-as-you-go in a single sweep — the user may want a narrower fix.
5. **Commit in one shot** with a single message that names each touched
   skill and what was removed, generalized, or moved.

## Where session-specific knowledge actually belongs

| Kind of fact | Right home |
|--------------|-----------|
| "Mission `pln-…` is the active one" | `maestro status --json`, `.maestro/tasks/NOW.md` |
| "We decided to do X on date Y" | `history/<date>-<slug>.md` or commit message |
| "Step Z broke because of bug Q" | `post-mortem` skill output (one-shot, not a guide) |
| "User prefers terse commit messages" | memory (durable user preference) |
| "Add `cursor.features.foo.enable = true`" | `engineering/assay-run-tests` skill (reusable across any feature add) |
| "Our `…}:` rewrap happened because of treefmt vX.Y" | commit message, changelog — not a skill |

## Why this matters

A `SKILL.md` that pins itself to one workstream:

- **Goes stale the moment that workstream ends.** The next reader sees
  "Active mission: X" and assumes X is still active, or assumes the skill
  is wrong when X is finished. Either way, the skill is now misleading.
- **Forces the next editor to either accept the stale literal or audit
  git history to decide whether to update it.** That is a tax on every
  future session.
- **Pollutes the load context.** Every agent that loads the skill pays
  the token cost of workstream-specific prose that does not apply to
  them.

A guide is cheap to keep current because it captures **mechanism**, not
**state**. State belongs in the project tree where the next session will
look for it anyway.

## Worked example — when a session triggers a skill edit

Suppose a user adds a Maestro mission for workstream `definitively/` and
the agent learns, in the process, that "claims must use
`--skip-worktree` on this repo." Two things to do:

1. **In the workstream's record** (`.maestro/missions/<slug>.md` or the
   spec): note that this mission is the one currently using
   `--skip-worktree`, with the plan and the spec paths.
2. **In the `maestro` skill**: if `--skip-worktree` is not already there,
   add it as a generic rule in the "Do not" list — without naming the
   workstream, without pinning to a specific mission id.

If the user says "document this for next time", the first home is the
mission / commit message. The second home is the skill, but only as a
generic rule.
