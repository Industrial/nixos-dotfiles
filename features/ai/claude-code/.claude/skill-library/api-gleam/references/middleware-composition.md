---
title: Compose Middleware with Closure Wrapping
impact: HIGH
impactDescription: Correct execution order, lazy handler evaluation, atomic operations
tags: api, middleware, auth, rate-limiting, composition
---

## Compose Middleware with Closure Wrapping

Middleware layers wrap handlers in closures so each layer only executes if the previous one passes. The pattern is: auth → rate limit → handler, with each layer receiving the next as a `fn() -> Response`.

**Incorrect (flat middleware chain, handler always runs):**

```gleam
// router.gleam — handler runs before rate limit is checked
Post, ["api", "v1", "import"] -> {
  let ctx = middleware.require_auth(req, db)
  let _check = rate_limit.check(limiter, ctx.tenant_id)
  import_controller.import_product(req, db, ctx)
}
```

**Correct (nested closure wrapping):**

```gleam
// router.gleam — handler only runs if all middleware passes
Post, ["api", "v1", "import"] ->
  middleware.require_role(req, db, user.Admin, fn(ctx, tx) {
    let tid = ctx.tenant_id
    import_middleware.with_import_rate_limit(
      limiter,
      tid,
      "import",
      fn() { import_controller.import_product(req, tx, tid) },
    )
  })
```

**Why closures?** The handler is wrapped in `fn() -> Response` so it only executes if the rate limit check passes. If blocked, the handler never runs.

**Middleware composition patterns:**

```gleam
// Auth + handler
middleware.require_auth(req, db, fn(ctx, tx) {
  handler(req, tx, ctx.tenant_id)
})

// Auth + usage limits (atomic: check + creation in same transaction)
middleware.require_within_limits(req, db, "orders", 1, fn(ctx, tx) {
  order_controller.create(req, tx, ctx.tenant_id)
})

// Auth + role + usage limits
middleware.require_role_and_usage(req, db, user.Admin, "imports", 1, fn(ctx, tx) {
  import_controller.run(req, tx, ctx.tenant_id)
})
```

**Key insight:** Usage limit checks happen inside the tenant-scoped transaction. This ensures the check and the creation are atomic — if the check passes but creation fails, no usage is counted.

**Unsubscribed tenants:** If no subscription record exists (free tier, trial), middleware allows the request through. Billing is additive — absence of a subscription means no limits to enforce.
