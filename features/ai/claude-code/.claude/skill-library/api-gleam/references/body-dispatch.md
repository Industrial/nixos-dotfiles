---
title: Use Two-Phase JSON Decode for Body-Type Dispatch
impact: MEDIUM
impactDescription: Clean POST endpoint consolidation with type safety
tags: api, dispatch, json, decode, post, routing
---

## Use Two-Phase JSON Decode for Body-Type Dispatch

For POST endpoints that handle multiple operations, dispatch by a `type` field in the request body. Decode the type field first (phase 1), then delegate to type-specific handlers that decode the full body (phase 2).

**Incorrect (separate POST routes for each type):**

```gleam
// router.gleam — separate routes for each sync type
Post, ["api", "v1", "sync", "orders"] -> sync.sync_orders(req, db, tid)
Post, ["api", "v1", "sync", "products"] -> sync.sync_products(req, db, tid)
Post, ["api", "v1", "sync", "customers"] -> sync.sync_customers(req, db, tid)
```

**Correct (single route, two-phase decode):**

```gleam
// router.gleam
Post, ["api", "v1", "sync"] -> sync.create_sync_job(req, db, tid)

// sync_controller.gleam
pub fn create_sync_job(req: Request, db: Connection, tenant_id: Uuid) -> Response {
  use json_body <- wisp.require_json(req)

  // Phase 1: decode only the type field
  let type_decoder = {
    use job_type <- decode.field("type", decode.string)
    decode.success(job_type)
  }

  case decode.run(json_body, type_decoder) {
    Ok("orders") -> do_sync_orders(json_body, db, tenant_id)
    Ok("products") -> do_sync_products(json_body, db, tenant_id)
    Ok(unknown) ->
      error_response.handle(
        error.ValidationErr("Unknown type: " <> unknown),
      )
    Error(_) ->
      error_response.handle(
        error.ValidationErr("Missing required field: type"),
      )
  }
}

// Phase 2: type-specific handlers decode the full body
fn do_sync_orders(json_body: Dynamic, db: Connection, tid: Uuid) -> Response {
  // Decode order-specific fields from json_body
  // ...
}
```

**When to use:**

- Multiple POST operations on the same resource distinguished by a type/kind field
- Import endpoints that accept different formats (`"type": "csv"`, `"type": "json"`)
- Job creation endpoints with polymorphic payloads

**Key insight:** Pass the raw `Dynamic` to phase-2 handlers so they can decode type-specific fields without re-parsing the request body.
