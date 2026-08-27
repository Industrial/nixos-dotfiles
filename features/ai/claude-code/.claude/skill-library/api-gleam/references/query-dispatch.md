---
title: Dispatch GET Endpoints by Query Parameters
impact: MEDIUM
impactDescription: Cleaner route table, single endpoint for related queries
tags: api, dispatch, query-params, get, routing
---

## Dispatch GET Endpoints by Query Parameters

When consolidating multiple GET endpoints that operate on the same resource, dispatch by the presence of query parameters rather than creating separate path segments. A single `query()` function reads params and delegates to internal handlers.

**Incorrect (separate routes for related queries):**

```gleam
// router.gleam — cluttered with similar GET routes
Get, ["api", "v1", "products", "search"] -> products.search(req, db)
Get, ["api", "v1", "products", "index"] -> products.index(req, db)
Get, ["api", "v1", "products"] -> products.list(req, db)
```

**Correct (single route, dispatch by query params):**

```gleam
// router.gleam
Get, ["api", "v1", "products"] -> products.query(req, db)

// products_controller.gleam
pub fn query(req: Request, db: Connection) -> Response {
  let query_params = wisp.get_query(req)
  let q = get_query_param(query_params, "q")
  let term = get_query_param(query_params, "term")

  case q, term {
    Some(_), _ -> search(req, db)
    _, Some(_) -> index(req, db)
    None, None ->
      error_response.handle(
        error.ValidationErr("Missing required parameter: q or term"),
      )
  }
}
```

**When to use:**

- Multiple GET operations on the same resource distinguished by filters/search terms
- Query params naturally express the variation (search vs browse vs filter)

**When NOT to use:**

- Operations on different sub-resources (use path segments instead)
- POST/PUT/DELETE where the body already distinguishes intent (use body dispatch)
