---
name: writing-commit-messages
description: >-
  Writes conventional commit messages with type prefixes, scopes, and bodies
  that explain why. Use when committing, amending messages, fixing commitizen
  hook failures, or when the user asks for a commit message.
---

# Writing Commit Messages

Write commit messages useful for humans, changelog tools, and CI hooks (commitizen/commitlint).

## Format

```
<type>(<optional scope>): <subject>

<optional body>

<optional footer>
```

### Subject rules

- **50 characters or less** for the subject
- Imperative mood: `add feature` not `added` or `adding`
- No capital letter immediately after the type prefix
- No trailing period

### Types

| Type | When to use |
|------|-------------|
| `feat` | New user-facing feature |
| `fix` | Bug fix |
| `refactor` | Restructure without behavior change |
| `docs` | Documentation only |
| `test` | Add or update tests |
| `chore` | Build, CI, tooling, deps |
| `perf` | Performance improvement |
| `style` | Formatting, whitespace (not CSS) |
| `ci` | CI/CD pipeline changes |
| `revert` | Revert a previous commit |

### Scope (optional)

Area of the codebase: `feat(auth):`, `fix(api):`, `refactor(db):`

### Body (when needed)

Explain **why**, not what — the diff shows what:

```
fix(checkout): prevent duplicate order submissions

The submit button stayed enabled after the first click, allowing
duplicate Stripe charges.
```

### Footer (when needed)

```
BREAKING CHANGE: rename getUserById to findUser

Closes #456
```

## Breaking changes

1. Add `!` after type: `feat(api)!: change auth token format`
2. Add `BREAKING CHANGE:` footer with migration notes

## Examples

Good:

```
feat(dashboard): add real-time notification bell
fix: resolve race condition in websocket reconnect
refactor(api): consolidate error handling middleware
test: add integration tests for payment webhook
chore: upgrade typescript to 5.4
```

Bad: `fixed stuff`, `WIP`, `update`, `changes`

## When to commit

- One logical change per commit
- Do not mix refactor and feature work
- Do not commit half-working code — stash instead
- Commit often on feature branches; squash at merge if the team prefers

## HEREDOC template

```bash
git commit -m "$(cat <<'MSG'
fix(scope): concise summary

Optional body explaining why.
MSG
)"
```

Adapted from [awesome-cursor-skills](https://github.com/spencerpauly/awesome-cursor-skills).
