# TDD Commit Structure: RED → GREEN

Commit RED tests separately from GREEN implementation. This proves you wrote tests first and provides a verifiable TDD workflow.

## The Pattern

```bash
# Commit 1: RED - Failing tests (proof of test-first)
git add test/router_test.gleam
git commit -m "RED: Add tests for SPA catch-all routing

- Test SPA routes serve HTML shell
- Test API routes return 404 JSON (not HTML)
- Test path traversal protection
- All 20 tests FAIL (feature not implemented)"

# Commit 2: GREEN - Implementation (minimal code to pass)
git add src/router.gleam
git commit -m "GREEN: Implement SPA catch-all with API guard

- Add GET catch-all for SPA routes
- Add /api/* guard (404 for unknown API paths)
- Add cache headers to HTML shell
- All tests PASS"
```

## Why Separate Commits?

### 1. Proves Test-First Discipline

```bash
# View RED commit
$ git show bd28683
# Shows: +20 test functions, 0 implementation changes
# Proves: Tests written before code

# View GREEN commit
$ git show 3f2e2f7
# Shows: Implementation that makes tests pass
# Proves: Implementation driven by tests
```

### 2. Easy to Verify TDD Compliance

```bash
# Check if tests were added first
$ git log --oneline feature-branch
3f2e2f7 GREEN: Implement SPA catch-all
bd28683 RED: Add tests for SPA routing
a1b2c3d Initial commit

# Verify RED commit has only tests
$ git show bd28683 --name-only
test/router_test.gleam

# Verify GREEN commit has only implementation
$ git show 3f2e2f7 --name-only
src/router.gleam
```

### 3. Documents Expected Behavior

The RED commit is a specification:
- Lists all expected behaviors
- Shows test structure before implementation
- Demonstrates test coverage goals

## Commit Message Template

### RED Commit

```
RED: [Feature description]

- List expected behaviors
- Each bullet = one test or test group
- Note: All tests FAIL (feature not implemented)

[Optional: Why these behaviors matter]
```

### GREEN Commit

```
GREEN: [Implementation description]

- Minimal code to pass tests
- Key implementation decisions
- Note: All tests PASS

[Optional: Trade-offs or design notes]
```

## Example: RBAC Middleware

### RED Commit

```bash
git add test/rbac_test.gleam
git commit -m "RED: Add RBAC middleware tests

- Admin can create/update/delete products
- Owner can create/update/delete products
- Member can list products (read-only)
- Viewer can list products (read-only)
- Member cannot delete products (403)
- Viewer cannot create products (403)

All tests FAIL - require_role middleware not implemented"
```

### GREEN Commit

```bash
git add src/middleware/rbac.gleam src/router.gleam
git commit -m "GREEN: Implement RBAC middleware

- Add require_role middleware
- Integrate with router on protected routes
- Admin/Owner pass all checks
- Member/Viewer get 403 on mutations

All tests PASS"
```

## Workflow Steps

### 1. Start Feature Branch

```bash
git checkout -b feature/spa-catch-all
```

### 2. Write RED Tests

```gleam
// test/router_test.gleam
// Write all tests showing desired behavior

pub fn spa_routes_serve_html_test() {
  let req = simulate.get("/orders", [])
  let response = router.handle(req, ctx)

  response.status |> should.equal(200)
  // Test fails - no SPA route yet
}

pub fn api_routes_return_json_404_test() {
  let req = simulate.get("/api/unknown", [])
  let response = router.handle(req, ctx)

  response.status |> should.equal(404)
  // Test fails - no API guard yet
}
```

### 3. Verify Tests Fail

```bash
$ gleam test
✗ spa_routes_serve_html_test
✗ api_routes_return_json_404_test
20 failed
```

### 4. Commit RED

```bash
git add test/router_test.gleam
git commit -m "RED: Add tests for SPA catch-all routing

- SPA routes serve HTML shell
- API routes return 404 JSON
- Path traversal protection
- Cache headers on HTML shell

All 20 tests FAIL"
```

### 5. Implement (Minimal Code)

```gleam
// src/router.gleam
pub fn handle(req: Request) -> Response {
  case wisp.path_segments(req), req.method {
    // API guard BEFORE catch-all
    _, ["api", ..] -> wisp.not_found()

    // SPA catch-all for GET requests
    Get, _ -> serve_admin_html()

    // Other methods
    _ -> wisp.method_not_allowed([Get])
  }
}
```

### 6. Verify Tests Pass

```bash
$ gleam test
✓ spa_routes_serve_html_test
✓ api_routes_return_json_404_test
20 passed
```

### 7. Commit GREEN

```bash
git add src/router.gleam
git commit -m "GREEN: Implement SPA catch-all with API guard

- Add /api/* guard before catch-all
- Add GET catch-all for SPA routes
- Add cache-control headers to HTML shell

All tests PASS"
```

## Code Review Benefits

Reviewers can:
1. Read RED commit - understand requirements
2. Read GREEN commit - verify minimal implementation
3. Confirm test coverage matches requirements

```bash
# Review RED commit
$ git show bd28683
# See: All expected behaviors as tests

# Review GREEN commit
$ git show 3f2e2f7
# See: Implementation that matches tests
```

## Anti-Patterns

### Mixed RED/GREEN (Don't do this)

```bash
# WRONG - tests and implementation in same commit
git add test/router_test.gleam src/router.gleam
git commit -m "Add SPA catch-all routing with tests"

# Problem: Can't verify test-first discipline
# Could have written code first, then added tests
```

### GREEN Without RED (Don't do this)

```bash
# WRONG - implementation without prior tests
git add src/router.gleam
git commit -m "Add SPA catch-all routing"

# Problem: No proof tests existed before implementation
```

## Rule

Every feature needs TWO commits minimum:
1. RED: Tests (failing)
2. GREEN: Implementation (passing)

Optional third commit:
3. REFACTOR: Cleanup (tests still passing)

**Source:** Kafka lessons.md (2026-02-12 SPA Catch-All Router)
