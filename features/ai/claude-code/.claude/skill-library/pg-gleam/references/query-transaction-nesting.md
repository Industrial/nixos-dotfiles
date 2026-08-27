---
title: Never Nest pog.transaction Calls
impact: CRITICAL
impactDescription: Silent data corruption from unexpected transaction commits
tags: transactions, pog, gleam, concurrency, data-integrity
---

## Never Nest pog.transaction Calls

`pog.transaction` opens a BEGIN...COMMIT block. Calling it again with the same connection inside the callback triggers PostgreSQL's "already in transaction" warning, and the inner COMMIT commits the outer transaction, causing unexpected behavior and data corruption.

**Incorrect (nested transaction causes early commit):**

```gleam
// Middleware wraps ALL handlers in transaction
pub fn with_auth(req: Request, pool: Connection, handler: fn() -> Response) {
  pog.transaction(pool, fn(tx) {
    handler()  // Handler receives tx
  })
}

// Handler tries to start ANOTHER transaction - WRONG!
pub fn create_order(req: Request, tx: Connection) -> Response {
  pog.transaction(tx, fn(tx2) {
    // PostgreSQL WARNING: there is already a transaction in progress
    // Inner COMMIT here commits the OUTER transaction!
    sql.insert_order(tx2, order)
  })
  // Outer transaction already committed - unexpected!
}
```

**Correct (handlers use the existing transaction):**

```gleam
// Middleware wraps ALL handlers in transaction
pub fn with_auth(req: Request, pool: Connection, handler: fn(Connection) -> Response) {
  pog.transaction(pool, fn(tx) {
    handler(tx)  // Pass transactional connection
  })
}

// Handler uses the transactional connection directly
pub fn create_order(req: Request, tx: Connection) -> Response {
  // tx is already transactional - just use it
  sql.insert_order(tx, order)
  |> result.map(fn(_) { response.json_created(...) })
  |> result.map_error(error_response.handle)
}
```

**Prevention:** When middleware wraps handlers in `pog.transaction`, handlers must NEVER call `pog.transaction` themselves. Grep for `pog.transaction` in handler code - only middleware should call it.

**Source:** Kafka lessons.md (2026-02-10 PR #52)

Reference: [POG Documentation](https://hexdocs.pm/pog/)
