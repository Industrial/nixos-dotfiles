# Gleam Language Features

## Label Shorthand Syntax

When variable names match label names, omit the value:

```gleam
// Instead of:
User(name: name, age: age, role: role)

// Write:
User(name:, age:, role:)

// Works in function calls too:
calculate_total(quantity:, unit_price:, discount:)

// And in pattern matching:
case user {
  User(name:, age:, ..) -> io.println(name)
}
```

## `bool.lazy_guard` vs `bool.guard`

`bool.guard` eagerly evaluates the return value. Use `bool.lazy_guard` when the return value is expensive:

```gleam
// bool.guard - return value is always evaluated
use <- bool.guard(is_cached, cached_value)

// bool.lazy_guard - return value only computed when needed
use <- bool.lazy_guard(is_cached, fn() { expensive_computation() })
```

Use `bool.lazy_guard` when the early-return value involves function calls, IO, or allocation. Use `bool.guard` for simple literal values.

## `let assert` with Custom Messages

Partial pattern match that panics on failure. Add `as` for a descriptive crash message:

```gleam
let assert [first, ..] = items as "Expected non-empty list"
let assert Ok(value) = result as "Database query should not fail here"
```

Use sparingly — prefer proper `Result` handling when failure is realistic. Most appropriate in application code where you have strong guarantees, not in library code.

## `assert` for Test Assertions

```gleam
assert add(1, 2) == 3
assert list.length(items) > 0 as "Items should not be empty"
```

Primarily for test code.

## `todo` and `panic`

```gleam
// todo - marks unimplemented code (compiler warns, runtime crashes)
pub fn new_feature() {
  todo as "Implement token refresh logic"
}

// panic - crashes intentionally for "impossible" states
case impossible_state {
  _ -> panic as "This should never happen"
}
```

## `@deprecated` Attribute

```gleam
@deprecated("Use connect_v2 instead")
pub fn connect(url: String) -> Connection {
  // ...
}
```

The compiler emits warnings at call sites. Works on both functions and type variants.

## Tail Call Optimization

Gleam optimizes tail calls. Use accumulator pattern for recursive functions:

```gleam
// BAD - not tail recursive (builds up stack)
pub fn sum(list: List(Int)) -> Int {
  case list {
    [] -> 0
    [first, ..rest] -> first + sum(rest)
  }
}

// GOOD - tail recursive with accumulator
pub fn sum(list: List(Int)) -> Int {
  sum_loop(list, 0)
}

fn sum_loop(list: List(Int), acc: Int) -> Int {
  case list {
    [] -> acc
    [first, ..rest] -> sum_loop(rest, acc + first)
  }
}
```

In practice, prefer stdlib functions (`list.fold`, `list.map`, etc.) over manual recursion.

## Guard Limitations

Guards only support simple comparisons and boolean operators. They CANNOT contain function calls, case expressions, or blocks:

```gleam
// BAD - function call in guard (won't compile)
case value {
  x if string.length(x) > 5 -> "Long"  // ERROR
  _ -> "Short"
}

// GOOD - bind the result first
let len = string.length(value)
case value {
  _ if len > 5 -> "Long"
  _ -> "Short"
}
```

## Pipeline and Data-First Convention

The pipe `|>` passes the left side as the **first argument**. Gleam's stdlib is designed data-first:

```gleam
tokens
|> list.filter(is_valid)
|> list.map(token.id)
|> string.join(", ")

// When you need a different argument position, use capture:
value
|> string.append("prefix: ", _)  // value goes to second arg
```

When designing your own functions, put the "data" argument first to enable pipelining.

## Constant Expressions

The `<>` operator works in constant expressions:

```gleam
pub const greeting = "Hello"
pub const sentence = greeting <> " " <> "Joe" <> "!"
```

List prepending works in constants using spread syntax:

```gleam
pub const base = [2, 3, 4]
pub const extended = [1, ..base]
```

## Structural Equality

All Gleam types support structural equality with `==` out of the box. No need to implement comparison functions or derive traits:

```gleam
type Point { Point(x: Int, y: Int) }

Point(1, 2) == Point(1, 2)  // True
Point(1, 2) == Point(3, 4)  // False

// Works as dict keys too:
let points = dict.from_list([#(Point(0, 0), "origin")])
```
