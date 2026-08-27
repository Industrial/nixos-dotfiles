# Gleam Language Basics

## No `if` Statement

Gleam has no `if` expression. All conditional logic uses `case`:

```gleam
// WRONG - doesn't compile
if x > 0 { "positive" } else { "non-positive" }

// RIGHT - use case
case x > 0 {
  True -> "positive"
  False -> "non-positive"
}
```

## Import Syntax

Gleam requires explicit imports for types and constructors:

```gleam
import gleam/option.{type Option, None, Some}
import gleam/result
import myapp/messages.{type Event, Started, Stopped}
```

## Records

Create records with positional or labeled arguments:

```gleam
pub type User {
  User(name: String, age: Int, active: Bool)
}

let user = User("Alice", 30, True)                          // positional
let user = User(name: "Alice", age: 30, active: True)       // labeled
```

Update records with spread syntax (creates a NEW record — Gleam is immutable):

```gleam
State(..state, field_name: new_value)
```

Record update syntax works in constant definitions:

```gleam
pub const base_config = Config(host: "0.0.0.0", port: 8080)
pub const prod_config = Config(..base_config, port: 80)
```

List prepending works in constants using spread syntax:

```gleam
pub const base = [2, 3, 4]
pub const extended = [1, ..base]
```

## Result vs Option

- `Result(value, error)` with `Ok(value)` / `Error(reason)` — for operations that can fail
- `Option(a)` with `Some(value)` / `None` — for optional values

**Important**: Use `Result(a, Nil)` for fallible operations with no meaningful error info, NOT `Option`. Reserve `Option` for truly optional data (optional function arguments, optional record fields).
