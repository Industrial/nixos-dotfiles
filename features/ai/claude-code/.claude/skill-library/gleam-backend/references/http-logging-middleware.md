# HTTP Logging Middleware - Single Application Point

`log_middleware.with_logging` should ONLY appear in `router.gleam` at the top-level request handler. Domain handlers extract context but never wrap requests.

## The Problem

```gleam
// router.gleam - wraps ALL requests
pub fn handle(req: Request, db: Connection) -> Response {
  use _ctx, log_response <- log_middleware.with_logging(req, db)
  let response = dispatch(req, db)
  log_response(response, json.object([]))
}

// customer/handler.gleam - WRONG: wraps request AGAIN
pub fn create(req: Request, db: Connection, ctx: AuthContext) -> Response {
  use log_ctx, log_response <- log_middleware.with_logging(req, db)  // DUPLICATE!

  case create_customer(db, data) {
    Ok(customer) -> {
      let _ = log_service.audit_create(db, log_ctx, "customer", customer.id, json)
      log_response(response.json_created(customer), json.object([]))
    }
    Error(err) -> error_response.handle(err)
  }
}

// Result: DOUBLE logging - two DB entries for every request!
```

## Correct Pattern

### Router (ONLY place with with_logging)

```gleam
// router.gleam
import log_middleware

pub fn handle(req: Request, db: Connection) -> Response {
  // Single logging middleware application
  use _ctx, log_response <- log_middleware.with_logging(req, db)

  let response = case wisp.path_segments(req) {
    ["api", "customers"] -> customer.create(req, db, auth_ctx)
    ["api", "products"] -> product.list(req, db, auth_ctx)
    _ -> wisp.not_found()
  }

  log_response(response, json.object([]))
}
```

### Domain Handlers (extract context, never wrap)

```gleam
// customer/handler.gleam
import log_middleware

pub fn create(req: Request, db: Connection, ctx: AuthContext) -> Response {
  // Extract context from request (already wrapped by router)
  let log_ctx = log_middleware.context_from_request(req)

  case create_customer(db, ctx, data) {
    Ok(customer) -> {
      // Use extracted context for audit logging
      let _ = log_service.audit_create(
        db,
        log_ctx,
        "customer",
        customer.id,
        customer_view.to_json(customer),
      )
      response.json_created(customer_view.to_json(customer))
    }
    Error(err) -> error_response.handle(err)
  }
}
```

## Rule of Thumb

```gleam
// ✓ CORRECT - Router only
rg "with_logging" server/src/
// Should return:
// server/src/router.gleam:42:  use _ctx, log_response <- log_middleware.with_logging(req, db)
// server/src/middleware/log_middleware.gleam:15:pub fn with_logging(...)

// ✗ WRONG - Appears in handlers
rg "with_logging" server/src/
// Returns:
// server/src/router.gleam:42:...
// server/src/middleware/log_middleware.gleam:15:...
// server/src/customer/handler.gleam:67:  use log_ctx, log_response <- log_middleware.with_logging(...)
//                                          ^^^ DUPLICATE - REMOVE THIS
```

## Pattern Comparison

```gleam
// ROUTER PATTERN (single place)
pub fn handle(req: Request, db: Connection) -> Response {
  use _ctx, log_response <- log_middleware.with_logging(req, db)
  // Dispatch to handlers
  log_response(response, metadata)
}

// HANDLER PATTERN (extract only)
pub fn create_resource(req: Request, db: Connection) -> Response {
  let log_ctx = log_middleware.context_from_request(req)  // Extract
  // Handler logic with audit logging
  response.json_created(data)  // Handler returns response directly
}
```

## Side Effects Fixed

When removing duplicate `with_logging` from handlers:

1. Remove unused `gleam/list` import (if only used for log metadata)
2. Remove unused `log_response` callback parameter
3. Remove `log_middleware` import (if only used for `with_logging`)
4. Keep `log_middleware.context_from_request` for audit logging

## Detection

```bash
# Find all with_logging calls
rg "with_logging" server/src/ -A 2

# Should only appear in:
# 1. router.gleam (application)
# 2. log_middleware.gleam (definition)

# If it appears in domain handlers → remove it
```

**Source:** Kafka lessons.md (2026-02-08 Double HTTP Logging)
