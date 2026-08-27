---
title: Use Centralized Error Handler for Canonical Error Shape
impact: CRITICAL
impactDescription: Consistent error contract across all endpoints, safe error messages
tags: api, errors, error-handling, middleware, json
---

## Use Centralized Error Handler for Canonical Error Shape

Every error response must use the canonical shape `{"error": "Kind", "message": "text"}`. Never build custom JSON error responses in handlers or middleware — always route through the centralized `error_response.handle()`.

**Incorrect (custom error response in middleware):**

```gleam
// middleware.gleam — ad-hoc error shape
fn unauthorized_response(message: String) -> Response {
  json.object([#("error", json.string(message))])
  |> json.to_string_builder
  |> wisp.json_response(401)
}
```

This produces `{"error": "message text"}` — missing the `"Kind"` / `"message"` separation. Clients can't programmatically distinguish error types.

**Correct (centralized error handler):**

```gleam
// In any handler or middleware
error_response.handle(error.AuthenticationErr("Missing authorization header"))

// Or use domain-specific convenience wrappers
error_response.handle_auth_error(auth.TokenExpired)
```

This produces `{"error": "AuthenticationErr", "message": "Missing authorization header"}` with consistent shape, safe user-facing messages, and automatic logging.

**Why it matters:**

- Clients get a predictable error contract they can parse programmatically
- Error kind (`"AuthenticationErr"`, `"NotFoundErr"`) enables client-side error routing
- Centralized handler ensures sensitive details are never leaked in messages
- Logging happens automatically — no risk of silent errors
