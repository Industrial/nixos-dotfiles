# decode.map vs decode.then

Use `decode.map` for infallible transformations (pure functions). Use `decode.then` only when the transformation itself returns a `Decoder`.

## The Difference

```gleam
import gleam/json/decode

// decode.map: fn(a) -> b
// For pure transformations that can't fail
pub fn status_decoder() -> decode.Decoder(Status) {
  decode.string
  |> decode.map(parse_status)  // parse_status returns Status directly
}

fn parse_status(s: String) -> Status {
  case s {
    "pending" -> Pending
    "completed" -> Completed
    _ -> Unknown  // Catch-all default
  }
}

// decode.then: fn(a) -> Decoder(b)
// For transformations that need additional decoding
pub fn timestamp_decoder() -> decode.Decoder(Timestamp) {
  decode.int
  |> decode.then(fn(unix_seconds) {
    // Returns a Decoder, not a Timestamp
    decode.success(timestamp.from_unix_seconds(unix_seconds))
  })
}
```

## Common Mistake: Over-using decode.then

```gleam
// WRONG - unnecessary wrapping
fn status_decoder() -> decode.Decoder(PaymentIntentStatus) {
  decode.string
  |> decode.then(fn(s) {
    decode.success(parse_status(s))  // Extra wrapping!
  })
}

// CORRECT - simpler with decode.map
fn status_decoder() -> decode.Decoder(PaymentIntentStatus) {
  decode.string
  |> decode.map(parse_status)  // Pure function
}
```

## When to Use Each

### Use decode.map when:
- Transformation is a pure function: `fn(a) -> b`
- Cannot fail (use catch-all for unknown values)
- Examples: parsing enums, converting types, formatting

```gleam
// Enum parsing
decode.string |> decode.map(parse_role)

// Type conversion
decode.int |> decode.map(fn(n) { n * 100 })  // cents to units

// Formatting
decode.string |> decode.map(string.lowercase)
```

### Use decode.then when:
- Transformation returns a `Decoder(b)`
- Need to decode further based on intermediate value
- Conditional decoding logic

```gleam
// Conditional decoding based on type field
decode.field("type", decode.string)
|> decode.then(fn(type_) {
  case type_ {
    "user" -> user_decoder()
    "admin" -> admin_decoder()
    _ -> decode.fail("Unknown type")
  }
})

// Nested decoding
decode.field("data", decode.dynamic)
|> decode.then(fn(dynamic_data) {
  decode.run(dynamic_data, specific_decoder())
  |> result.map(decode.success)
  |> result.unwrap(decode.fail("Invalid data"))
})
```

## Pattern: Enum Decoders

```gleam
// Standard enum decoder pattern
pub type Status {
  Pending
  Processing
  Completed
  Failed
}

pub fn status_decoder() -> decode.Decoder(Status) {
  decode.string
  |> decode.map(fn(s) {
    case string.lowercase(s) {
      "pending" -> Pending
      "processing" -> Processing
      "completed" -> Completed
      "failed" -> Failed
      _ -> Pending  // Safe default for library code
    }
  })
}
```

## Why This Matters

- `decode.map` is simpler and more readable
- `decode.then` adds unnecessary lambda and wrapping
- Use the right tool for the job
- Code reviewers will flag over-use of `decode.then`

**Source:** Kafka lessons.md (2026-02-09 gstripe PaymentIntent)
