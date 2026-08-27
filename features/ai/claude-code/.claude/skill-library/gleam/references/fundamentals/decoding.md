# JSON Decoding

## Critical: Modern Decoder API

**ALWAYS use `gleam/dynamic/decode` instead of `gleam/dynamic`.**

The old `gleam/dynamic` module with `decode6`, `decode9`, `field()`, `optional_field()` is DEPRECATED.

```gleam
// CORRECT - Modern continuation-style API
import gleam/dynamic/decode

fn my_decoder() -> decode.Decoder(MyType) {
  use name <- decode.field("name", decode.string)
  use age <- decode.field("age", decode.int)
  use email <- decode.optional_field("email", None, decode.optional(decode.string))
  decode.success(MyType(name:, age:, email:))
}

// Nested field access with at:
use name <- decode.at(["user", "profile", "name"], decode.string)

// Try multiple decoders (first success wins):
let flexible_int = decode.one_of(decode.int, [
  decode.string |> decode.then(fn(s) {
    case int.parse(s) {
      Ok(i) -> decode.success(i)
      Error(_) -> decode.failure(0, "numeric string")
    }
  }),
])

// Optional fields with defaults:
use color <- decode.optional_field("color", "blue", decode.string)
// If "color" key is missing or null, uses "blue"
```

## Decoder Migration Guide

### Import Changes

```gleam
// Old
import gleam/dynamic.{type Dynamic}

// New
import gleam/dynamic/decode
```

### Type Changes

```gleam
// Old
fn my_decoder() -> dynamic.Decoder(MyType)

// New
fn my_decoder() -> decode.Decoder(MyType)
```

### Basic Decoders

| Old                     | New                    |
| ----------------------- | ---------------------- |
| `dynamic.string`        | `decode.string`        |
| `dynamic.int`           | `decode.int`           |
| `dynamic.float`         | `decode.float`         |
| `dynamic.bool`          | `decode.bool`          |
| `dynamic.list(decoder)` | `decode.list(decoder)` |

### Required Field

```gleam
// Old
dynamic.field("name", dynamic.string)

// New - continuation style
use name <- decode.field("name", decode.string)
// Then use `name` variable
```

### Optional Field

```gleam
// Old
dynamic.optional_field("email", dynamic.string)

// New - requires default value
use email <- decode.optional_field("email", None, decode.optional(decode.string))
```

**Important:** The new API requires THREE arguments:

1. Field name
2. Default value (used if field is missing)
3. Decoder wrapped in `decode.optional()`

### Old Style (decode2, decode3, ... decode9)

```gleam
// Old - positional arguments
fn user_decoder() -> dynamic.Decoder(User) {
  dynamic.decode3(
    User,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("email", dynamic.string),
  )
}
```

### New Style (continuation)

```gleam
// New - named bindings with continuation
fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(id:, name:, email:))
}
```

## Complex Example

### Before (Old API)

```gleam
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

pub type Order {
  Order(
    id: Int,
    customer_name: String,
    items: List(OrderItem),
    notes: Option(String),
  )
}

pub type OrderItem {
  OrderItem(product_id: Int, quantity: Int, price: Float)
}

fn order_decoder() -> dynamic.Decoder(Order) {
  dynamic.decode4(
    Order,
    dynamic.field("id", dynamic.int),
    dynamic.field("customer_name", dynamic.string),
    dynamic.field("items", dynamic.list(item_decoder())),
    dynamic.optional_field("notes", dynamic.string),
  )
}

fn item_decoder() -> dynamic.Decoder(OrderItem) {
  dynamic.decode3(
    OrderItem,
    dynamic.field("product_id", dynamic.int),
    dynamic.field("quantity", dynamic.int),
    dynamic.field("price", dynamic.float),
  )
}
```

### After (New API)

```gleam
import gleam/dynamic/decode
import gleam/option.{type Option, None}

pub type Order {
  Order(
    id: Int,
    customer_name: String,
    items: List(OrderItem),
    notes: Option(String),
  )
}

pub type OrderItem {
  OrderItem(product_id: Int, quantity: Int, price: Float)
}

fn order_decoder() -> decode.Decoder(Order) {
  use id <- decode.field("id", decode.int)
  use customer_name <- decode.field("customer_name", decode.string)
  use items <- decode.field("items", decode.list(item_decoder()))
  use notes <- decode.optional_field("notes", None, decode.optional(decode.string))
  decode.success(Order(id:, customer_name:, items:, notes:))
}

fn item_decoder() -> decode.Decoder(OrderItem) {
  use product_id <- decode.field("product_id", decode.int)
  use quantity <- decode.field("quantity", decode.int)
  use price <- decode.field("price", decode.float)
  decode.success(OrderItem(product_id:, quantity:, price:))
}
```

## Handling Union Types (one_of)

When a field might have different types:

```gleam
// Decode either float or int as Float
fn float_or_int_decoder() -> decode.Decoder(Float) {
  decode.one_of(decode.float, [
    decode.int |> decode.map(int.to_float),
  ])
}
```

## Custom Decoders with Validation

```gleam
fn uuid_decoder() -> decode.Decoder(Uuid) {
  decode.string
  |> decode.then(fn(s) {
    case uuid.from_string(s) {
      Ok(id) -> decode.success(id)
      Error(_) -> decode.failure(uuid.v7(), "Uuid")
    }
  })
}
```

## JSON Parsing

```gleam
// Old
json.decode(json_string, my_decoder())

// New
json.parse(json_string, my_decoder())
```

Note: `json.decode` is REMOVED. Use `json.parse` instead.

## Decoding Dynamic Values

```gleam
// Old
decode.run(dynamic_value, my_decoder())

// New - same!
decode.run(dynamic_value, my_decoder())
```

## Common Mistakes

### Mistake 1: Forgetting decode.optional wrapper

```gleam
// WRONG - will not compile
use email <- decode.optional_field("email", None, decode.string)

// CORRECT
use email <- decode.optional_field("email", None, decode.optional(decode.string))
```

### Mistake 2: Wrong number of arguments to optional_field

```gleam
// WRONG - missing default value
use email <- decode.optional_field("email", decode.optional(decode.string))

// CORRECT - three arguments
use email <- decode.optional_field("email", None, decode.optional(decode.string))
```

### Mistake 3: Using old json.decode

```gleam
// WRONG - function doesn't exist
json.decode(str, decoder)

// CORRECT
json.parse(str, decoder)
```

## Migration Checklist

- [ ] Change import from `gleam/dynamic` to `gleam/dynamic/decode`
- [ ] Change return type from `dynamic.Decoder(T)` to `decode.Decoder(T)`
- [ ] Replace `decodeN` functions with continuation style
- [ ] Update `field` calls to use `use <- decode.field(...)`
- [ ] Update `optional_field` to include default value and `decode.optional` wrapper
- [ ] Replace `json.decode` with `json.parse`
- [ ] Run `gleam check` to verify no errors
