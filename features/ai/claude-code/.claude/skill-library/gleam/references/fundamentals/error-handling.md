# Error Handling

## Error Handling Discipline

**NEVER silently discard errors.** Silent error discards make debugging impossible.

- **NEVER write `Error(_) ->`** — always bind the error and log it:
  ```gleam
  // WRONG
  Error(_) -> default_value

  // RIGHT
  Error(err) -> {
    logging.log(logging.Warning, "context: " <> string.inspect(err))
    default_value
  }
  ```

- **NEVER write `fn(_err) {`** in error handlers — bind and log:
  ```gleam
  // WRONG
  result.map_error(fn(_) { DatabaseError })

  // RIGHT
  result.map_error(fn(err) {
    wisp.log_error("create_product: " <> string.inspect(err))
    DatabaseError
  })
  ```

- **Exception**: `Error(_)` is OK when the error type is `Nil` (e.g., `int.parse`, `dict.get`) since there's nothing to inspect. `Ok(_)` to discard success values is also fine.

## The Error Contract: Typed Codes, Not Prose

Errors that cross a boundary (entity → handler → client) are **typed values**, not strings. Two rules keep the channel honest:

1. **No prose baked into the error.** A variant names *what* went wrong (`TitleRequired`, `EmailAlreadyExists`); it does not carry a pre-rendered English sentence. Human-readable, localized text is produced at the *presentation* layer — on the client for UI, in the log line for operators — by mapping the code. The same `EmailAlreadyExists` renders as "E-mail já cadastrado" or "Email already in use" depending on the viewer; bake the English in and you have hard-coded one locale into your domain.
2. **The client never receives English on the error channel.** The server sends a stable machine **code** (plus any structured data the client needs); the client owns the code → message table.

```gleam
// BAD — prose baked into the error; ships one hard-coded locale to the client
pub type ProductError {
  ValidationFailed(String)   // Error(ValidationFailed("Title is required"))
}

// GOOD — payload-free typed codes; the *variant* is the message
pub type ProductError {
  NotFound(id: Uuid)         // structured data (an id) is fine; English prose is not
  TitleRequired
  TitleTooLong
  HandleAlreadyTaken
  DatabaseError              // payload-free; log the raw cause where you catch it
}
```

A variant may carry **structured** data the consumer needs (an id, a count, a limit) — `NotFound(id: Uuid)`, `TooManyItems(limit: Int)`. It must not carry a rendered message string.

> **Why payload-free?** A closed set of typed codes is exhaustively matchable (the compiler finds every `case` when you add a variant — see anti-pattern A9), trivially mappable to an HTTP status, and localizable on the client. A `String` payload is none of these.

## Philosophy: Errors as Values

Gleam uses `Result` types for error handling. There are no exceptions. Every function that can fail returns `Result(SuccessType, ErrorType)`.

## Domain-Specific Errors

Create domain-specific error types in your entity modules — as **typed codes**, not message carriers:

```gleam
// catalog/product.gleam
pub type ProductError {
  NotFound(id: Uuid)
  TitleRequired
  TitleTooLong
  HandleAlreadyTaken
  DatabaseError
}

// auth/session.gleam
pub type SessionError {
  InvalidCredentials
  EmailAlreadyExists
  Expired
  InvalidToken
}
```

These are self-documenting and pattern-matched precisely. At the handler boundary, map them to an HTTP status and a wire **code** — never to an English sentence baked in server-side.

## The One Open-String Channel: the Decode Boundary

There is exactly one place a free-form string is legitimate on the error channel: **decoding an untrusted request body or path**, where the offending field name is not known until runtime. Mint a single dedicated variant there:

```gleam
pub type AppError {
  // ... typed domain codes ...
  RequestBodyInvalid(field: String, code: String)   // ONLY at the decode boundary
}
```

- `field` is the JSON/path location that failed (`"email"`, `"items.0.qty"`).
- `code` is a *machine* token (`"required"`, `"not_an_email"`), **not** a sentence.

Mint `RequestBodyInvalid` only inside the `require_json` / body-decode / `path_id` helpers. Everywhere deeper in the stack, use the typed domain codes above. This keeps the open-string surface to a single, auditable boundary.

## Application Error Type

Wrap domain errors in one application-level type that also carries the decode-boundary channel and cross-cutting codes:

```gleam
// error/error.gleam

import catalog/product
import auth/session

pub type AppError {
  // Domain error wrappers
  ProductErr(product.ProductError)
  SessionErr(session.SessionError)

  // The single open-string channel (decode boundary only):
  RequestBodyInvalid(field: String, code: String)

  // Cross-cutting typed codes (no String prose):
  Unauthenticated
  Forbidden
  RateLimited
  Internal
}
```

**Note:** For your specific project, rename `AppError` to something project-specific like `AcmeError`, `ShopError`, or `MyAppError`. This avoids confusion with generic "Error" types.

## Helper Functions

Map each error to (1) an HTTP status and (2) a stable wire **code**. There is deliberately **no `message` helper that returns English** — rendering belongs to the viewer (client or log), not the error module.

```gleam
/// HTTP status code for an error
pub fn to_status_code(error: AppError) -> Int {
  case error {
    ProductErr(product.NotFound(_)) -> 404
    ProductErr(product.TitleRequired) -> 422
    ProductErr(product.TitleTooLong) -> 422
    ProductErr(product.HandleAlreadyTaken) -> 409
    ProductErr(product.DatabaseError) -> 500
    SessionErr(session.InvalidCredentials) -> 401
    SessionErr(session.EmailAlreadyExists) -> 409
    SessionErr(session.Expired) -> 401
    SessionErr(session.InvalidToken) -> 401
    RequestBodyInvalid(_, _) -> 422
    Unauthenticated -> 401
    Forbidden -> 403
    RateLimited -> 429
    Internal -> 500
  }
}

/// Stable machine code for the wire + logs (NOT user-facing prose)
pub fn to_code(error: AppError) -> String {
  case error {
    ProductErr(product.NotFound(_)) -> "product.not_found"
    ProductErr(product.TitleRequired) -> "product.title_required"
    ProductErr(product.TitleTooLong) -> "product.title_too_long"
    ProductErr(product.HandleAlreadyTaken) -> "product.handle_taken"
    ProductErr(product.DatabaseError) -> "product.database_error"
    SessionErr(session.InvalidCredentials) -> "session.invalid_credentials"
    SessionErr(session.EmailAlreadyExists) -> "session.email_exists"
    SessionErr(session.Expired) -> "session.expired"
    SessionErr(session.InvalidToken) -> "session.invalid_token"
    RequestBodyInvalid(_, _) -> "request_body_invalid"
    Unauthenticated -> "unauthenticated"
    Forbidden -> "forbidden"
    RateLimited -> "rate_limited"
    Internal -> "internal"
  }
}
```

Match every variant explicitly (anti-pattern A9) — when you add an error, the compiler points you at both helpers.

## Error Response Module

Convert an error to an HTTP response. The **log** line (for operators) may include English and full detail; the **body** (for the client) carries only the code plus any structured fields.

```gleam
// error/response.gleam

import error/error.{type AppError}
import error/view as error_view
import gleam/string
import wisp

pub fn handle(err: AppError) -> wisp.Response {
  // Operators get detail — string.inspect keeps the full typed value
  wisp.log_error(error.to_code(err) <> ": " <> string.inspect(err))

  wisp.response(error.to_status_code(err))
  |> wisp.set_header("content-type", "application/json")
  |> wisp.string_body(error_view.to_json_string(err))
}
```

## Error View Module

Serialize to JSON as **code + structured fields** — no English:

```gleam
// error/view.gleam

import error/error.{type AppError}
import gleam/json

pub fn to_json(err: AppError) -> json.Json {
  json.object([#("code", json.string(error.to_code(err))), ..extra_fields(err)])
}

pub fn to_json_string(err: AppError) -> String {
  to_json(err) |> json.to_string
}

/// Only the structured data a client needs to localize or act — never prose.
fn extra_fields(err: AppError) -> List(#(String, json.Json)) {
  case err {
    error.RequestBodyInvalid(field, code) -> [
      #("field", json.string(field)),
      #("detail", json.string(code)),
    ]
    _ -> []
  }
}
```

On the client, decode `code` back into a typed `ErrorCode` and render the localized message — the client owns the locale table:

```gleam
// client side — wire code -> typed code -> localized text
fn message_for(code: ErrorCode, lang: Language) -> String {
  case code, lang {
    ProductTitleRequired, Portuguese -> "Título é obrigatório"
    ProductTitleRequired, English -> "Title is required"
    // ...
  }
}
```

The server shipped no English; the client owns every user-facing string.

## Error Propagation Pattern

Use `result.try` to chain operations that might fail. Mint `RequestBodyInvalid` at the decode boundary; map domain errors with their wrappers deeper in.

```gleam
import gleam/result

pub fn process_request(req: Request, db: Connection) -> Response {
  let result = {
    // Decode boundary — the one place an open-string code is legitimate
    use user_id <- result.try(
      uuid.from_string(req.user_id)
      |> result.replace_error(error.RequestBodyInvalid("user_id", "not_a_uuid"))
    )

    use tenant_id <- result.try(
      uuid.from_string(req.tenant_id)
      |> result.replace_error(error.RequestBodyInvalid("tenant_id", "not_a_uuid"))
    )

    // Entity layer — returns a typed domain error
    use data <- result.try(
      product.get(db, user_id, tenant_id)
      |> result.map_error(error.ProductErr)
    )

    Ok(view.to_json(data))
  }

  case result {
    Ok(json) -> json_response(json, 200)
    Error(err) -> error_response.handle(err)
  }
}
```

## Layer-Specific Error Handling

### Handler Layer

HTTP handlers parse requests, call entity functions, and map errors to HTTP responses. Decode failures become `RequestBodyInvalid`; domain failures keep their typed codes.

```gleam
// catalog/handler.gleam
pub fn create(req: Request, db: Connection, tenant_id: String) -> Response {
  use json_body <- wisp.require_json(req)

  let result = {
    use tid <- result.try(
      uuid.from_string(tenant_id)
      |> result.replace_error(error.RequestBodyInvalid("tenant_id", "not_a_uuid"))
    )
    // A real request_body helper maps each decode.DecodeError to a precise
    // field path + machine code; minted only here, at the decode boundary.
    use data <- result.try(
      decode.run(json_body, view.decoder())
      |> result.map_error(fn(_errs) {
        error.RequestBodyInvalid(field: "body", code: "invalid")
      })
    )
    // Call entity function — map domain error to app error
    product.create(db, tid, data)
    |> result.map_error(error.ProductErr)
  }

  case result {
    Ok(record) -> {
      wisp.response(201)
      |> wisp.set_header("content-type", "application/json")
      |> wisp.string_body(json.to_string(view.to_json(record)))
    }
    Error(err) -> error_response.handle(err)
  }
}
```

### Entity Layer

Entity modules contain types, pure functions, and database operations. They return **typed domain codes** — and log the raw cause where they catch it, so the payload-free `DatabaseError` stays code-only:

```gleam
// catalog/product.gleam
pub type ProductError {
  NotFound(id: Uuid)
  TitleRequired
  TitleTooLong
  HandleAlreadyTaken
  DatabaseError
}

/// Create a product — returns a typed domain code
pub fn create(db: pog.Connection, tenant_id: Uuid, data: CreateRequest)
  -> Result(sql.CreateProductRow, ProductError) {
  case string.is_empty(data.title) {
    True -> Error(TitleRequired)
    False -> {
      case sql.create_product(db, tenant_id, data.title, data.handle) {
        Ok(returned) -> extract_first(returned, tenant_id)
        Error(err) -> {
          wisp.log_error("sql.create_product: " <> string.inspect(err))
          Error(DatabaseError)
        }
      }
    }
  }
}

fn extract_first(returned: pog.Returned(a), id: Uuid) -> Result(a, ProductError) {
  case returned.rows {
    [row] -> Ok(row)
    [] -> Error(NotFound(id))
    _ -> Error(DatabaseError)
  }
}
```

## Converting External Errors

When integrating with external services that have their own error types, map them to your typed codes (never pass their strings through to the client):

```gleam
// Map external error to app error
fn external_to_error(e: ExternalError) -> error.AppError {
  case e {
    external.NetworkError(_) -> error.Internal
    external.NotFound -> error.ProductErr(product.NotFound(uuid.v7()))
    external.RateLimited -> error.RateLimited
    external.Unauthorized -> error.Unauthenticated
  }
}
```

## Best Practices

### 1. Name the failure, don't describe it

```gleam
// Bad — prose on the error channel
Error(ValidationFailed("Email must be a valid email address"))

// Good — a typed code; the client renders the locale-specific message
Error(SessionErr(session.InvalidCredentials))
// At the decode boundary only:
Error(error.RequestBodyInvalid("email", "not_an_email"))
```

### 2. Don't Expose Internal Details

```gleam
// Bad — leaks internal structure to the client
Error(error.RequestBodyInvalid("body", "pog.QueryError: constraint violation"))

// Good — a payload-free code; log the real cause where you catch it
Error(Internal)
// wisp.log_error("...: " <> string.inspect(raw_error))
```

### 3. Use Appropriate Error Types

```gleam
// Wrong — generic code for a domain concept
Error(error.Internal)

// Correct — the specific domain code
Error(error.ProductErr(product.NotFound(id)))
```

### 4. Early Return on Error

```gleam
// Use result.try for early return
use user <- result.try(get_user(db, user_id))
use permissions <- result.try(get_permissions(db, user.id))
use _ <- result.try(check_permission(permissions, "create"))
// Only reaches here if all succeeded
```

### 5. Log Errors at the Right Level

- **Handler**: Log the typed code + `string.inspect` before returning the HTTP response.
- **Entity**: Log the raw cause where a payload-free code (e.g. `DatabaseError`) is minted, so the code stays prose-free upstream.
- **SQL/View**: Don't log (let the handler/entity boundary handle it).
