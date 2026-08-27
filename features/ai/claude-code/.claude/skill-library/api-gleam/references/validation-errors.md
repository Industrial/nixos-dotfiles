---
title: Map ValidationErr to 400 and Decode Errors to 422
impact: HIGH
impactDescription: Correct HTTP semantics for client error handling
tags: api, errors, validation, http-status, error-handling
---

## Map ValidationErr to 400 and Decode Errors to 422

Use `error.ValidationErr` for all request validation errors (missing params, invalid values) — it returns HTTP 400. Reserve 422 (Unprocessable Entity) for JSON decode errors where the body structure itself is malformed.

**Incorrect (wrong status codes):**

```gleam
// Handler returning 422 for a missing query param
case params.get_required(query_params, "email") {
  Error(_) -> wisp.unprocessable_content()  // 422 — wrong!
  Ok(email) -> // ...
}

// Test expecting 422 for validation
response.status |> should.equal(422)  // Will fail — handler returns 400
```

**Correct (ValidationErr for validation, 422 for decode):**

```gleam
// Validation error → 400 via centralized handler
case params.get_required(query_params, "email") {
  Error(_) ->
    error_response.handle(
      error.ValidationErr("Missing required parameter: email"),
    )
  Ok(email) -> // ...
}

// JSON decode error → 422
case decode.run(json_body, order_decoder) {
  Error(_) -> wisp.unprocessable_content()  // 422 — body structure is wrong
  Ok(order) -> // ...
}
```

**Status code mapping:**

| Scenario | Error type | HTTP status |
| --- | --- | --- |
| Missing/invalid query param | `error.ValidationErr` | 400 |
| Invalid UUID format | `error.ValidationErr` | 400 |
| Invalid email format | `error.ValidationErr` | 400 |
| Missing required field | `error.ValidationErr` | 400 |
| Malformed JSON body | `wisp.unprocessable_content()` | 422 |
| Wrong field types in body | `wisp.unprocessable_content()` | 422 |

**Rule:** Always use `error.ValidationErr` through the centralized error handler — it ensures canonical error shape, safe messages, and logging. Only use `wisp.unprocessable_content()` directly for structural JSON decode failures.
