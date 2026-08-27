---
title: Use Shared JSON Helpers for Consistent Serialization
impact: HIGH
impactDescription: Consistent API data contract, prevents format drift across endpoints
tags: api, json, serialization, timestamps, metadata
---

## Use Shared JSON Helpers for Consistent Serialization

All JSON serialization must use shared helpers from `helper/http/json.gleam`. Never define local serialization functions in view modules — this causes format drift (e.g., some endpoints return Unix timestamps while others return RFC 3339 strings).

**Incorrect (local timestamp helper in view module):**

```gleam
// order_view.gleam — local helper produces Unix integers
fn timestamp_to_json(ts: pog.Timestamp) -> json.Json {
  json.int(timestamp.to_unix(ts))
}

pub fn to_json(order: Order) -> json.Json {
  json.object([
    #("created_at", timestamp_to_json(order.created_at)),
    // ...
  ])
}
```

**Correct (shared helpers for all types):**

```gleam
// order_view.gleam — uses canonical helpers
pub fn to_json(order: Order) -> json.Json {
  json.object([
    #("created_at", json_helper.timestamp(order.created_at)),
    #("deleted_at", json_helper.option_timestamp(order.deleted_at)),
    #("metadata", metadata.to_json(order.metadata)),
    #("notes", json_helper.option_string(order.notes)),
  ])
}
```

**Timestamp helpers** (all in `helper/http/json.gleam`):

| Helper | Input | Output | Use for |
| --- | --- | --- | --- |
| `json_helper.timestamp(ts)` | `pog.Timestamp` | `json.Json` (RFC 3339) | Required timestamp fields |
| `json_helper.option_timestamp(opt)` | `Option(pog.Timestamp)` | `json.Json` or `null` | Nullable timestamp fields |
| `json_helper.timestamp_string(ts)` | `pog.Timestamp` | `String` | Shared type string fields |
| `json_helper.option_timestamp_string(opt)` | `Option(pog.Timestamp)` | `Option(String)` | Shared record fields |

**Metadata vs option_string:**

- `metadata.to_json(opt)` — returns `json.object([])` for `None` (metadata is always an object)
- `json_helper.option_string(opt)` — returns `json.null()` for `None` (standard nullable field)

Use `metadata.to_json()` for metadata fields where clients expect an object. Use `json_helper.option_string()` for regular optional strings.
