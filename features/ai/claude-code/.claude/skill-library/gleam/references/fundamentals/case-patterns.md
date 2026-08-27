# Case Expression Patterns

Gleam has several features that replace verbose nested case expressions.

## Nested Pattern Matching

```gleam
// BAD - nested case
case message {
  ConnectionDown(down) ->
    case down {
      process.ProcessDown(monitor:, ..) -> handle_down(monitor)
      process.PortDown(..) -> continue(state)
    }
}

// GOOD - nested pattern in single case
case message {
  ConnectionDown(process.ProcessDown(monitor:, ..)) -> handle_down(monitor)
  ConnectionDown(process.PortDown(..)) -> continue(state)
}
```

## option.map for Transforming Values (NOT Side Effects)

```gleam
// GOOD - transforming a value
option.map(tag, json.string) |> option.unwrap(json.null())

// BAD - using map for side effects (the `let _ =` is a code smell!)
let _ = option.map(state.timer, process.cancel_timer)
```

**Rule**: If you're writing `let _ = option.map(...)` or `let _ = result.map(...)`, you're misusing map. Use explicit `case` for side effects:

```gleam
case state.timer {
  Some(timer) -> process.cancel_timer(timer)
  None -> Nil
}
```

For Results with real errors, always log:

```gleam
// BAD
let _ = result.map(channel.summon(registry, id, redis), channel.apply_patches(_, patches))

// GOOD
case channel.summon(registry, id, redis) {
  Ok(ch) -> channel.apply_patches(ch, patches)
  Error(err) -> logging.log(logging.Warning, "failed to summon: " <> string.inspect(err))
}
```

## option.unwrap for Default Values

```gleam
// BAD
let value = case maybe_value {
  Some(v) -> v
  None -> default
}

// GOOD
let value = option.unwrap(maybe_value, default)
```

## option.flatten for Option(Option(a))

```gleam
// BAD
case nested_option {
  Some(inner) -> inner
  None -> None
}

// GOOD
option.flatten(nested_option)
```

## option.lazy_or for "Keep Existing or Create New"

```gleam
// BAD
let timer = case state.timer {
  Some(t) -> Some(t)
  None -> Some(create_new_timer())
}

// GOOD
let timer = option.lazy_or(state.timer, fn() { Some(create_new_timer()) })
```

## result.map + result.unwrap for "Transform or Default"

```gleam
// BAD
case dict.get(map, key) {
  Ok(value) -> transform(value)
  Error(_) -> default
}

// GOOD
dict.get(map, key)
|> result.map(transform)
|> result.unwrap(default)
```

## Guards for Boolean Conditions

```gleam
// OK - separate case on boolean
case status {
  Ok(user) ->
    case is_admin {
      True -> show_admin_panel(user)
      False -> show_home(user)
    }
  Error(_) -> redirect_to_login()
}

// BETTER - guard clause
case status {
  Ok(user) if is_admin -> show_admin_panel(user)
  Ok(user) -> show_home(user)
  Error(_) -> redirect_to_login()
}
```

## Multiple Subjects

```gleam
case username, password {
  "", "" -> Error("Both fields required")
  "", _ -> Error("Username required")
  _, "" -> Error("Password required")
  user, pass -> validate(user, pass)
}
```

## bool.guard for Early Returns (Booleans Only)

Use `bool.guard` when checking a **boolean condition**, not matching values:

```gleam
// BAD - case on True/False
case string.is_empty(token) {
  True -> decode.failure(Identify(""), "Token is empty")
  False -> decode.success(Identify(token))
}

// GOOD - early return with bool.guard
use <- bool.guard(string.is_empty(token), decode.failure(Identify(""), "Token is empty"))
decode.success(Identify(token))
```

**BUT** use `case` when matching actual values:

```gleam
// GOOD - matching on a specific value (0), not True/False
case subscribers.size(connections) {
  0 -> stop_actor(state)
  _ -> continue(state)
}

// BAD - converting to boolean just to use bool.guard
use <- bool.guard(subscribers.size(connections) != 0, continue(state))
stop_actor(state)
```

## Extracting Nested Boolean Checks

When you have multiple boolean checks nested inside a pattern match arm, extract them into a helper function using `bool.guard`:

```gleam
// BEFORE - Hard to read, deeply nested
case validate_input(data) {
  Ok(parsed) -> {
    case check_permission(user, parsed) {
      True -> {
        case is_within_quota(user) {
          True -> process(parsed)
          False -> Error("Quota exceeded")
        }
      }
      False -> Error("Permission denied")
    }
  }
  Error(e) -> Error(e)
}

// AFTER - Clear preconditions, flat structure
case validate_input(data) {
  Ok(parsed) -> process_with_checks(user, parsed)
  Error(e) -> Error(e)
}

fn process_with_checks(user: User, parsed: Input) -> Result(Output, String) {
  use <- bool.guard(!check_permission(user, parsed), Error("Permission denied"))
  use <- bool.guard(!is_within_quota(user), Error("Quota exceeded"))
  Ok(process(parsed))
}
```

**Benefits:**
- Flattens deeply nested structure into linear flow
- Each guard represents a clear precondition
- Function name documents the purpose of grouped checks
- Easier to test validation logic in isolation
- Follows "parse, don't validate" principle when used with opaque types

**When to keep `case` instead:**
- Only one boolean check (extraction adds unnecessary indirection)
- Boolean checks have side effects that must execute in specific order
- Matching on specific values, not True/False (see section above)

## Record Constructors as Functions

Record constructors are functions. Use them directly:

```gleam
// BAD
|> result.map(fn(subject) { TokenHandle(subject:) })

// GOOD
|> result.map(TokenHandle)

// Works with partial application via capture:
list.map(names, User(name: _, role: "admin"))
```

## Function Captures (Partial Application)

```gleam
// These are equivalent:
let add_one = fn(x) { add(1, x) }
let add_one = add(1, _)

// Works in pipelines:
list.map(users, string.append("Hello, ", _))
```

Only a single `_` is allowed per capture expression.

## Alternative Patterns with `|`

```gleam
case number {
  2 | 4 | 6 | 8 -> "Even"
  1 | 3 | 5 | 7 -> "Odd"
  _ -> "Other"
}

case event {
  ChannelDeleted(_) | ChannelRevoked(_) -> handle_removal()
  StateUpdated(state) -> handle_update(state)
}
```

All alternatives must bind the same variable names with the same types.

## Pattern Aliases with `as`

```gleam
case lists {
  [[_, ..] as first, ..] -> first
  _ -> []
}

case message {
  ConnectionDown(process.ProcessDown(monitor:, ..) as down) -> {
    handle_down(down)
  }
  _ -> continue(state)
}
```

## String Prefix Matching with `<>`

```gleam
case command {
  "subscribe:" <> channel_name -> subscribe(channel_name)
  "unsubscribe:" <> channel_name -> unsubscribe(channel_name)
  _ -> Error("Unknown command")
}
```

The left side must be a string literal. The right side captures the remainder.
