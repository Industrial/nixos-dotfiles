# Three-Tier Database Error Handling

Separate concerns: full logging for debugging, safe messages for users, structured errors for application logic. Never leak PostgreSQL internals to clients.

## The Problem

```gleam
// WRONG - leaks PG error codes, constraint names, table names
case pog.execute(sql, db, params, decoder) {
  Error(pog.PostgresqlError(code, name, message)) -> {
    // Raw PG error exposed to client!
    response.json_error(400, message)
  }
  Ok(result) -> response.json(result)
}
```

## Three-Tier Pattern

### Tier 1: Full Logging (Internal Only)

```gleam
import wisp

pub fn log_query_error(err: pog.QueryError) -> Nil {
  case err {
    pog.PostgresqlError(code, name, message) -> {
      wisp.log_error(
        "Database error: code="
        <> code
        <> " constraint="
        <> name
        <> " message="
        <> message,
      )
    }
    pog.ConnectionUnavailable -> {
      wisp.log_error("Database connection unavailable")
    }
    pog.ConstraintViolated(constraint, message) -> {
      wisp.log_error("Constraint violated: " <> constraint <> " - " <> message)
    }
  }
}
```

### Tier 2: Safe String Messages

```gleam
pub fn query_error_message(err: pog.QueryError) -> String {
  // Log first (for debugging)
  log_query_error(err)

  // Return safe message (no internals)
  case err {
    pog.PostgresqlError(_, _, _) -> "Database error occurred"
    pog.ConnectionUnavailable -> "Database temporarily unavailable"
    pog.ConstraintViolated(_, _) -> "Data constraint violation"
  }
}
```

### Tier 3: Structured Domain Errors

```gleam
pub type DbError {
  DatabaseError(String)
  ConstraintViolation(String)
  NotFound(String)
}

pub fn map_query_error(err: pog.QueryError, entity: String) -> DbError {
  // Log first
  log_query_error(err)

  // Map to domain error (safe)
  case err {
    pog.PostgresqlError(_, _, _) -> DatabaseError("Failed to access " <> entity)
    pog.ConnectionUnavailable -> DatabaseError("Database unavailable")
    pog.ConstraintViolated(_, _) -> ConstraintViolation(entity <> " constraint violated")
  }
}
```

## Usage Patterns

### Pattern 1: Direct Error Response

```gleam
pub fn create_order(req: Request, db: Connection) -> Response {
  case sql.insert_order(db, params) {
    Ok(order) -> response.json_created(order)
    Error(db_err) -> {
      // Logs internally, returns safe message
      let message = db.query_error_message(db_err)
      response.json_error(500, message)
    }
  }
}
```

### Pattern 2: Result Pipeline with Structured Errors

```gleam
pub fn update_product(id: String, data: ProductData, db: Connection) -> Result(Product, AppError) {
  sql.update_product(db, id, data)
  |> result.map_error(fn(db_err) {
    // Logs internally, returns domain error
    AppError(ProductErr(db.map_query_error(db_err, "product")))
  })
}
```

### Pattern 3: Centralized Error Handler

```gleam
// error_response.gleam
pub fn handle(err: AppError) -> Response {
  case err {
    DatabaseError(msg) -> {
      // Already logged by map_query_error
      response.json_error(500, "An unexpected error occurred")
    }
    ConstraintViolation(msg) -> {
      response.json_error(400, "Invalid operation")
    }
    NotFound(msg) -> {
      response.json_error(404, "Resource not found")
    }
  }
}
```

## Extract Helper Pattern

```gleam
// db.gleam - shared helpers
pub fn extract_one(
  result: Result(List(a), pog.QueryError),
  entity: String,
) -> Result(a, DbError) {
  case result {
    Ok([item]) -> Ok(item)
    Ok([]) -> Error(NotFound(entity <> " not found"))
    Ok(_) -> Error(DatabaseError("Multiple " <> entity <> " rows found"))
    Error(err) -> Error(map_query_error(err, entity))
  }
}

// Usage
sql.get_product_by_id(db, id)
|> db.extract_one("product")
```

## Defense-in-Depth

Even though `error_response.handle()` sanitizes errors, the three-tier pattern provides defense-in-depth:

1. **Logging tier** - Full PG details for debugging (server logs only)
2. **Safe message tier** - Generic messages, no PG internals
3. **Error handler tier** - Final sanitization before HTTP response

This prevents leakage if any code path bypasses the error handler.

## Rule

- **NEVER** return raw `pog.QueryError` to clients
- **ALWAYS** log PG internals before mapping to safe errors
- **Use Tier 2** for ad-hoc error messages
- **Use Tier 3** for result pipelines with structured errors

**Source:** Kafka lessons.md (2026-02-10 PR #50)
