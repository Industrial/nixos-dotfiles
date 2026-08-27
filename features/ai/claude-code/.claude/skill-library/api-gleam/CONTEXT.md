# api-gleam — REST/JSON API patterns for Gleam
> Last updated: 2026-04-25

Battle-tested REST/JSON API design patterns for Gleam web services
using Wisp and Mist. Covers route naming, error responses, pagination,
serialization, request dispatch, and middleware composition.

Inherits: `skills/CONTEXT.md`.

## Layout
```
api-gleam/
├── SKILL.md
└── references/
    ├── route-naming.md          # REST nouns, plural resources
    ├── error-responses.md       # Canonical error shape (CRITICAL)
    ├── validation-errors.md     # 400 vs 422 distinction
    ├── json-serialization.md    # Timestamps, metadata, optional fields
    ├── pagination-hal.md        # HAL-style pagination
    ├── query-dispatch.md        # Query parameter dispatch
    ├── body-dispatch.md         # POST body type dispatch
    ├── spa-routing.md           # Serve SPA alongside API
    ├── middleware-composition.md # Auth + rate limiting + handler
    └── _template.md             # Template for new references
```

## Common Wisp gotchas

- **`wisp.path_segments(req)` returns the FULL path**, not relative to
  mount. Mounted at `/api/v1`, request for `/api/v1/orders/123` gives
  `["api", "v1", "orders", "123"]`
- **There is no `get_header`.** Use `list.key_find(req.headers, name)`.
  Header names are always lowercase

## Reference routing
| Task                                | Reference              |
|-------------------------------------|------------------------|
| Name a new route                    | `route-naming.md`      |
| Return an error from a handler      | `error-responses.md`   |
| Distinguish 400 vs 422             | `validation-errors.md` |
| Add pagination to a list endpoint   | `pagination-hal.md`    |
| Serialize timestamps or metadata    | `json-serialization.md`|
| Merge multiple GET endpoints        | `query-dispatch.md`    |
| Dispatch POST by body type          | `body-dispatch.md`     |
| Serve SPA alongside API             | `spa-routing.md`       |
| Compose auth + rate limiting        | `middleware-composition.md` |
