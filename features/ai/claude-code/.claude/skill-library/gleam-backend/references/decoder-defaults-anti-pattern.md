# Never Hardcode Decoder Defaults for API Fields

Always decode fields from API responses. Never hardcode complex field defaults (metadata, lists, nested objects) when the API provides that data.

## The Problem

```gleam
// WRONG - hardcoded metadata in ALL Stripe object decoders
pub fn payment_intent_decoder() -> Decoder(PaymentIntent) {
  use id <- decode.field("id", decode.string)
  use amount <- decode.field("amount", decode.int)
  use currency <- decode.field("currency", decode.string)
  use status <- decode.field("status", decode.string)

  decode.success(PaymentIntent(
    id: id,
    amount: amount,
    currency: currency,
    status: parse_status(status),
    metadata: [],  // ← HARDCODED! Data loss!
  ))
}

// Result: Stripe sends metadata, but it's silently dropped
```

## Correct Pattern

```gleam
pub fn payment_intent_decoder() -> Decoder(PaymentIntent) {
  use id <- decode.field("id", decode.string)
  use amount <- decode.field("amount", decode.int)
  use currency <- decode.field("currency", decode.string)
  use status <- decode.field("status", decode.string)

  // Decode metadata from API response
  use metadata <- decode.optional_field(
    "metadata",
    [],  // Default only for ABSENT field
    decode.dict(decode.string, decode.string) |> decode.map(dict.to_list),
  )

  decode.success(PaymentIntent(
    id: id,
    amount: amount,
    currency: currency,
    status: parse_status(status),
    metadata: metadata,  // ← Decoded from response
  ))
}
```

## Builder vs Decoder Defaults

### Builder Defaults (CORRECT)

```gleam
// Request builders - defaults are CORRECT
pub fn session_params() -> SessionParams {
  SessionParams(
    mode: "payment",
    success_url: "",
    cancel_url: "",
    metadata: [],  // ← Correct: caller provides no metadata
  )
}

pub fn with_metadata(params: SessionParams, metadata: List(#(String, String))) -> SessionParams {
  SessionParams(..params, metadata: metadata)
}
```

### Decoder Defaults (WRONG)

```gleam
// Response decoders - defaults are BUGS
pub fn session_decoder() -> Decoder(Session) {
  use id <- decode.field("id", decode.string)
  use url <- decode.field("url", decode.string)

  decode.success(Session(
    id: id,
    url: url,
    metadata: [],  // ← WRONG: ignores API data!
  ))
}
```

## How to Fix

### 1. Find Hardcoded Defaults

```bash
# Search for hardcoded empty lists/dicts in decoders
rg "metadata: \[\]" src/
rg "tags: \[\]" src/
rg "items: \[\]" src/

# Check if these are in decoder functions
rg "_decoder\(\)" src/ -A 20 | grep "metadata: \[\]"
```

### 2. Add decode.optional_field

```gleam
// Before: hardcoded default
decode.success(Type(metadata: []))

// After: decode from response
use metadata <- decode.optional_field(
  "metadata",
  [],  // Default for ABSENT field only
  decode.dict(decode.string, decode.string) |> decode.map(dict.to_list),
)
decode.success(Type(metadata: metadata))
```

### 3. Test with Real API Responses

```gleam
pub fn decode_metadata_test() {
  let json = "{
    \"id\": \"pi_123\",
    \"amount\": 1000,
    \"currency\": \"usd\",
    \"status\": \"succeeded\",
    \"metadata\": {\"order_id\": \"ord_456\", \"tenant_id\": \"ten_789\"}
  }"

  let assert Ok(intent) = json.decode(json, payment_intent_decoder())

  // Metadata should be decoded, not empty!
  intent.metadata |> should.equal([
    #("order_id", "ord_456"),
    #("tenant_id", "ten_789"),
  ])
}
```

## Rule of Thumb

### Hardcode defaults ONLY when:
- ✓ Field is truly absent from API response
- ✓ Builder functions (request params)
- ✓ Internal data structures (not from external APIs)

### NEVER hardcode defaults for:
- ✗ Metadata fields (always decode)
- ✗ Tags/labels (API provides them)
- ✗ Nested lists (decode or use `optional_field`)
- ✗ Any field that exists in API docs

## Detection in Code Review

```gleam
// Red flag: decoder with hardcoded complex defaults
pub fn stripe_object_decoder() -> Decoder(StripeObject) {
  // ...
  decode.success(StripeObject(
    // ...
    metadata: [],           // ← Red flag
    tags: [],              // ← Red flag
    line_items: [],        // ← Red flag
    custom_fields: dict.new(),  // ← Red flag
  ))
}

// Green flag: decoded with optional fallback
pub fn stripe_object_decoder() -> Decoder(StripeObject) {
  use metadata <- decode.optional_field("metadata", [], metadata_decoder)
  use tags <- decode.optional_field("tags", [], decode.list(decode.string))
  // ...
  decode.success(StripeObject(metadata: metadata, tags: tags, ...))
}
```

**Source:** Kafka lessons.md (2026-02-09 gstripe metadata hardcoding)
