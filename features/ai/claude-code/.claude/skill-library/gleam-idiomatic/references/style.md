# Idiomatic Gleam style

General style rules for clear, debuggable Gleam code. Sourced from [Dream Test AGENTS.md](https://raw.githubusercontent.com/TrustBound/dream_test/refs/heads/main/AGENTS.md) and [STANDARDS.md](https://raw.githubusercontent.com/TrustBound/dream_test/main/STANDARDS.md); only the general rules apply (not project-specific APIs).

## Config records for multi-parameter functions

When a function has many parameters (3+), or several parameters of the same type, use a config record with named fields instead of a long positional list. Named fields are self-documenting and reduce argument-order mistakes.

**Do:** Define a record and pass it in.

```gleam
let config = RunConfig(name: "example", tags: [], run: my_test)
run_single_test(config)
```

**Don't:** Long positional argument lists.

```gleam
run_single_test("example", [], my_test)
```

## No nested case expressions

Do not nest `case` expressions. Extract the inner logic into a named helper function. Flat structure improves readability, testability, and stack traces.

**Do:** One `case` per function; call helpers for inner branching.

```gleam
pub fn handle(value1, value2) {
  case value1 {
    Some(x) -> handle_with_value(x, value2)
    None -> handle_none()
  }
}

fn handle_with_value(x, value2) {
  case value2 {
    Ok(y) -> do_something(x, y)
    Error(e) -> handle_error(e)
  }
}
```

**Don't:** Nested `case` in a single function.

## No closures or anonymous functions in library code

In library code (e.g. under `src/`), do not use closures (functions that capture outer scope) or anonymous `fn() { ... }`. Define all functions at module level with explicit parameters. This makes data flow and dependencies explicit and simplifies testing.

**Do:** Named top-level functions with explicit parameters.

```gleam
pub fn is_less_than(limit, value) {
  value < limit
}
```

**Don't:** Closures or inline anonymous functions in library modules.

(Test or script code may use anonymous functions where the project allows.)

## No abbreviated identifiers

Use full, descriptive names. Avoid: `ctx` (use `context`), `res` (use `result`), `f` (use `failure`), `cfg` (use `config`), `msg` (use `message`), `val` (use `value`).

## Option vs Result

In Gleam, all **fallible functions** should return `Result`, not `Option`. Use `Nil` as the error type when there is no extra detail to give.

- This keeps APIs consistent and predictable.
- It avoids boilerplate converting between `Option` and `Result`.

Use `Option` only for **optional values** that are passed into functions as arguments or stored in data structures (e.g. `Option(String)` field on a record), not for reporting failure of an operation.

## Import style

- Prefer unqualified imports for frequently used DSL or pipe-friendly functions.
- Use `type Foo` when importing types so the type is in scope; import both type and constructor when needed: `import foo.{type Bar, Bar}`.
- Use `as` only when two modules have the same final name and you need to disambiguate. Do not alias purely for shortening (e.g. avoid `import dream_test/matchers as should`).

## Pipes over fluent builders

Functions should take concrete arguments and return values — not return other functions for chaining. Pipe-first code is idiomatic.

**Do:** Pipe through functions that take value and return value.

```gleam
value
|> should
|> be_equal(expected)
|> or_fail_with("message")
```

**Don't:** Fluent/curried style where helpers return functions.

```gleam
value |> should.be_equal(expected)
```

## Module and file organization

For small Gleam codebases (for example, under ~1000 lines), start with a single, cohesive module instead of eagerly splitting into many files just because it is a "web app" or something like that. In general Gleam projects should keep related business logic together and only split modules when real reuse or complexity appears.

**Do:** Extract modules based on reuse and dependencies.

- Shared HTML rendering helpers
- Form-building helpers
- Functions that operate on a shared data structure or domain type

**Don't:** Split one business workflow across many tiny modules without clear boundaries.

Split things out **from** your business logic (reusable helpers, shared data-structure code), not split up the business logic itself.
