# Do / don't examples

Short pairs for common Gleam patterns.

## Config record vs long positional list

**Don't:**

```gleam
run_single_test("passing test", full_name, tags, types.Unit, passing_test)
```

**Do:**

```gleam
let config = SingleTestConfig(
  name: "passing test",
  full_name: ["bootstrap", "runner_core"],
  tags: ["bootstrap", "runner"],
  kind: types.Unit,
  run: passing_test,
)
run_single_test(config)
```

---

## Flat case with helper vs nested case

**Don't:**

```gleam
case value1 {
  Some(x) ->
    case value2 {
      Ok(y) -> do_something(x, y)
      Error(e) -> handle_error(e)
    }
  None -> handle_none()
}
```

**Do:**

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

---

## List append (no concat)

**Don't:** There is no `list.concat` in Gleam.

**Do:**

```gleam
list.append(left_list, right_list)
list.append(name_prefix, [name])
```

---

## Type import

**Don't:** Forgetting `type` leads to "no type in scope with that name" when you use the name as a type.

**Do:**

```gleam
import foo.{type Bar, Bar}
let x: Bar = Bar(1)
```

---

## Pipe-friendly vs fluent/curried

**Don't:** Fluent style where a helper returns a function.

```gleam
value |> should.be_equal(expected)
```

**Do:** Pipe through functions that take value and return value.

```gleam
value |> should |> be_equal(expected) |> or_fail_with("message")
```
