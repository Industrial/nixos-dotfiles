# Standard Library Module Names

Common mistakes with Gleam stdlib module names. These modules have changed or use unexpected names.

## Common Name Mismatches

### gleam/regexp (not gleam/regex)

```gleam
// WRONG - module doesn't exist
import gleam/regex

// CORRECT
import gleam/regexp

pub fn validate_pattern(text: String) -> Bool {
  let assert Ok(re) = regexp.from_string("^[a-z]+$")
  regexp.check(re, text)
}
```

### result.try (not result.then)

```gleam
// WRONG - function doesn't exist
result.then(some_result, fn(value) { ... })

// CORRECT - use result.try for monadic bind
result.try(some_result, fn(value) { ... })

// Or with use syntax (idiomatic)
use value <- result.try(some_result)
// ... rest of code
```

### wisp/simulate (not wisp/testing)

```gleam
// WRONG - module doesn't exist
import wisp/testing as simulate

// CORRECT
import wisp/simulate

pub fn test_endpoint() {
  let req = simulate.get("/api/users", [])
  let req = simulate.header(req, "authorization", "Bearer token")
  // ...
}
```

### simulate.header (not simulate.set_header)

```gleam
import wisp/simulate
import gleam/http/request

// WRONG - simulate doesn't have set_header
let req = simulate.set_header(req, "auth", "token")

// CORRECT - use simulate.header
let req = simulate.header(req, "authorization", "Bearer token")

// For non-test code, use request.set_header from gleam/http
let req = request.set_header(req, "authorization", "Bearer token")
```

## Quick Reference

| Wrong | Correct | Notes |
|-------|---------|-------|
| `gleam/regex` | `gleam/regexp` | Regular expressions |
| `result.then` | `result.try` | Monadic bind for Results |
| `wisp/testing` | `wisp/simulate` | Test request builders |
| `simulate.set_header` | `simulate.header` | Add headers to test requests |
| `option.then` | `option.map` or `option.then` | `then` exists but `map` is for simple transforms |

## Why This Matters

- Import errors cause compilation failures
- Function name errors also fail at compile time
- These are common mistakes when coming from other languages
- Search/replace can help: `rg "gleam/regex" src/` to find violations

## Prevention

1. Always check [Gleam package docs](https://hexdocs.pm/gleam_stdlib/) for exact module names
2. Use LSP autocomplete to verify function names
3. Read compiler errors carefully - they often suggest the correct name

**Source:** Kafka lessons.md (2026-02-08 to 2026-02-12, multiple occurrences)
