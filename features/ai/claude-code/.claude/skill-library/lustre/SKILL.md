---
name: lustre
description: Gleam frontend development skill targeting JavaScript. Covers Lustre 5.x, MVU Architecture, Advanced Forms (save-lifecycle state machines/FieldState), UI Patterns, SPA Routing (modem), and HTTP requests (rsvp). Use when building UI or working in client/src/.
---

# Lustre & Frontend Best Practices

Skill for Gleam frontend development using Lustre. **Read the relevant reference before writing code.**

## Token Efficiency
**All agents and commands using this skill MUST follow `references/token-efficiency.md` (from core).** Use `Read` and `Grep` tools with targeted reads instead of reading entire files.

## Reference routing — by task

| Task                          | References to read                                                               |
|-------------------------------|----------------------------------------------------------------------------------|
| Frontend MVU Forms & UI       | `advanced-mvu-forms.md` + `lustre-ui-patterns.md`                                |
| Frontend Web Components       | `lustre-components.md`                                                           |
| Frontend HTTP / API calls     | `lustre-http.md`                                                                 |
| Frontend SPA Routing          | `lustre-routing.md`                                                              |

## Reference routing — by topic

| Topic                                    | Reference                                       |
|------------------------------------------|-------------------------------------------------|
| Lustre MVU Core Architecture             | `lustre-core.md`                                |
| Lustre Effects & Paint cycle             | `lustre-effects.md`                             |
| Lustre Events (debounce, throttle)       | `lustre-events.md`                              |
| Lustre Testing (query, simulate)         | `lustre-testing.md`                             |
| Lustre Browser APIs (plinth)             | `lustre-browser-apis.md`                        |
| Lustre Advanced (Hydration, FFI)         | `lustre-advanced.md`                            |
| Common Lustre gotchas                    | `lustre-gotchas.md`                             |

## Core Frontend Principles

1. **Make Impossible States Impossible** — Prefer sum types over Bools. Especially for async lifecycles: a form's save is `SubmitIdle | SubmitSaving | SubmitSaved | SubmitFailed(err)` (the model owns its data + a sibling `save` field); a page load is `RemoteData`. Never a `Bool` flag beside the data.
2. **Parse, Don't Validate** — Use `FieldState(v, e)` to wrap invalid UI state, rather than dictionaries.
3. **Dumb Effects** — Effects should be pure executors of I/O. Never pass the `Model` into an effect function.
