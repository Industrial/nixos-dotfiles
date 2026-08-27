# lustre — Gleam Frontend Skill
> Last updated: 2026-05-16

Covers the JavaScript target, including Lustre MVU, Advanced Forms, routing, HTTP, and Web Components.

Inherits: `skills/CONTEXT.md`.

## Layout
```
lustre/
├── SKILL.md                         # Main prompt with decision trees
└── references/                      # JavaScript target — Lustre
    ├── advanced-mvu-forms.md    # Save lifecycle (Submit), FieldState, parameterization
    ├── lustre-core.md           # MVU architecture, state, messages
    ├── lustre-effects.md        # Effects, paint cycle
    ├── lustre-routing.md        # SPA routing (modem)
    ├── lustre-http.md           # HTTP requests (rsvp)
    ├── lustre-components.md     # Web components, slots, CSS parts
    ├── lustre-events.md         # Events, debounce, throttle
    ├── lustre-ui-patterns.md    # Composable UI, prop pattern
    ├── lustre-advanced.md       # Hydration, server components, FFI
    ├── lustre-browser-apis.md   # Browser APIs (plinth)
    ├── lustre-testing.md        # Testing (query, simulate, birdie)
    └── lustre-gotchas.md        # Common Lustre gotchas
```

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

## Common Lustre Gotchas
- **Prefer sum types over `Bool` fields in model state.** Aligns with MVU conventions. For a form, the model owns its data and carries a sibling `save: Submit` (`SubmitIdle | SubmitSaving | SubmitSaved | SubmitFailed(err)`); for a page load, use `RemoteData`. Never a `saving: Bool`.
- **Never pass `Model` to Effects.** Extract the needed primitives in the `update` loop.
