# TDD in Compile-Time Languages

In compile-time languages like Gleam, you can't call non-existent functions - the test file won't compile. Write tests against **behavior** (HTTP status codes, return values), not function names directly.

## The Challenge

```gleam
// WRONG - This won't compile if require_role doesn't exist yet
import middleware/rbac

pub fn viewer_cannot_create_product_test() {
  let token = create_viewer_token()

  // Compile error: rbac.require_role doesn't exist!
  rbac.require_role(token, user.Admin)
  |> should.be_error
}
```

## The Solution: Test Behavior, Not Functions

```gleam
// CORRECT - Test HTTP behavior through the router
import router
import wisp/simulate
import gleam/http

pub fn viewer_cannot_create_product_test() {
  let assert Ok(token) = test_helper.create_token_for_role(user.Viewer)

  // Test HTTP status code (behavior)
  let req = simulate.post(
    "/api/rest/v1/products",
    [simulate.header(_, "authorization", "Bearer " <> token)],
    "{\"name\":\"Widget\",\"sku\":\"WDG-001\"}"
  )

  let response = router.handle(req, test_ctx.db, test_ctx.limiter)

  // RED: Route uses require_auth (no role check) → returns 400/422 (validation error)
  // GREEN: After adding require_role → returns 403 (forbidden)
  response.status |> should.equal(403)
}
```

## TDD Workflow for Middleware

### Step 1: RED - Write Tests (Compile + Fail)

```gleam
// All tests compile but fail because route has no role check yet

pub fn admin_can_create_product_test() {
  let assert Ok(token) = test_helper.create_token_for_role(user.Admin)
  let req = test_helper.authenticated_json_request(
    http.Post,
    "/api/rest/v1/products",
    token,
    "{\"name\":\"Widget\",\"sku\":\"WDG-001\"}",
  )

  let response = router.handle(req, ctx.db, ctx.limiter)

  // Passes (admin gets through require_auth)
  response.status |> should.not_equal(403)
}

pub fn viewer_cannot_create_product_test() {
  let assert Ok(token) = test_helper.create_token_for_role(user.Viewer)
  let req = test_helper.authenticated_json_request(
    http.Post,
    "/api/rest/v1/products",
    token,
    "{\"name\":\"Widget\",\"sku\":\"WDG-001\"}",
  )

  let response = router.handle(req, ctx.db, ctx.limiter)

  // RED: Currently returns 400/422 (no role check), expects 403
  response.status |> should.equal(403)
}
```

**Verify RED:**

```bash
$ gleam test
✓ admin_can_create_product_test (passes - admin gets through)
✗ viewer_cannot_create_product_test
  Expected: 403
  Got: 422
```

### Step 2: GREEN - Implement Middleware

```gleam
// middleware/rbac.gleam
pub fn require_role(
  req: Request,
  db: Connection,
  min_role: user.Role,
  handler: fn(AuthContext) -> Response,
) -> Response {
  case auth.extract_token(req) {
    Error(_) -> unauthorized_response()
    Ok(token_string) -> {
      case auth.validate_token(token_string, db) {
        Error(_) -> unauthorized_response()
        Ok(ctx) -> {
          case user.has_role(ctx.role, min_role) {
            True -> handler(ctx)
            False -> forbidden_response()  // Now returns 403!
          }
        }
      }
    }
  }
}
```

**Verify GREEN:**

```bash
$ gleam test
✓ admin_can_create_product_test
✓ viewer_cannot_create_product_test  // Now passes!
```

## Pattern: Test Through Public API

```gleam
// Don't test internal middleware directly
// DO test HTTP status codes through router

pub fn owner_can_delete_tenant_test() {
  let assert Ok(token) = test_helper.create_token_for_role(user.Owner)

  let req = test_helper.authenticated_request(
    http.Delete,
    "/api/rest/v1/tenant",
    token,
  )

  let response = router.handle(req, ctx.db)

  response.status |> should.equal(204)
}

pub fn member_cannot_delete_tenant_test() {
  let assert Ok(token) = test_helper.create_token_for_role(user.Member)

  let req = test_helper.authenticated_request(
    http.Delete,
    "/api/rest/v1/tenant",
    token,
  )

  let response = router.handle(req, ctx.db)

  response.status |> should.equal(403)
}
```

## Pattern: Assert Success Status Range

```gleam
// "Can do" tests - don't assert specific success codes
pub fn owner_can_create_product_test() {
  let assert Ok(token) = test_helper.create_token_for_role(user.Owner)

  let req = test_helper.authenticated_json_request(
    http.Post,
    "/api/rest/v1/products",
    token,
    valid_product_json,
  )

  let response = router.handle(req, ctx.db)

  // Success could be 201 (created) or 200 (ok)
  // Don't assert specific code, just "not forbidden"
  response.status |> should.not_equal(403)
}

// "Cannot do" tests - assert specific 403
pub fn viewer_cannot_create_product_test() {
  let assert Ok(token) = test_helper.create_token_for_role(user.Viewer)

  let req = test_helper.authenticated_json_request(
    http.Post,
    "/api/rest/v1/products",
    token,
    valid_product_json,
  )

  let response = router.handle(req, ctx.db)

  // Forbidden tests assert exact code
  response.status |> should.equal(403)
}
```

## Why This Works

1. **Tests compile** - No reference to non-existent function
2. **RED phase works** - Tests fail because behavior is wrong (no role check)
3. **GREEN phase works** - Adding middleware makes tests pass
4. **Behavior-focused** - Tests what users experience (HTTP codes), not internals

## Key Insight

In **compile-time languages**, the RED phase means:
- ✓ Tests **compile** (no type errors)
- ✓ Tests **fail** (wrong behavior)

NOT:
- ✗ Tests don't compile (function missing)

Write tests that compile but fail due to missing behavior.

**Source:** Kafka lessons.md (2026-02-08 RBAC Middleware)
