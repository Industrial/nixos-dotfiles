# Common Pitfalls

1. **No function calls in guards** — extract to variable first
2. **Prefix unused arguments** with underscore: `_req`
3. **Prefix enum variants** to avoid conflicts across types
4. **`timestamp.to_unix_seconds()` returns Float**, not Int
5. **Argon2 hashes have random salts** — never compare hashes directly, use `antigone.verify()`
6. **`timestamp.now()` doesn't exist** — use `timestamp.system_time()`
7. **Using `===` instead of `==`** — JavaScript habit, Gleam uses `==`
8. **Using `if` instead of `case`** — Gleam has no `if` expression
9. **Discarding return values** — immutability means `set_header(req, ...)` returns a new request; you must use the return value
10. **Creating process names dynamically** — causes atom table overflow and VM crash
11. **Overusing catch-all `_` patterns** — hides unhandled cases when types change; always bind and log errors
12. **Nesting Results** instead of using `use` expressions with `result.try`
13. **Using `Option` for fallible operations** — use `Result(a, Nil)` instead; reserve `Option` for truly optional data
14. **`list.range` is deprecated** — use `int.range` instead. Key differences: `list.range(1, 5)` returns `[1, 2, 3, 4, 5]` (both-inclusive, returns List), while `int.range(from: 1, to: 5, with: acc, run: reducer)` iterates `1..4` (from-inclusive, to-exclusive, reducer-style). Adjust upper bound by +1 when migrating. To build a list: `int.range(from: 1, to: 6, with: [], run: list.prepend)`
15. **Mock UUIDs with version nibble 0 fail `uuid.from_bit_array()`** — `youid` only recognizes UUID versions 1–5, 7. Hand-crafted UUIDs like `a0010000-0000-0000-0000-000000000001` have version 0 and are rejected. The resulting `DecodeError("Uuid", "String", ...)` is misleading — "String" comes from Erlang classifying all binaries as strings. Use `uuid_generate_v7()` in SQL or `uuid.v7()` in Gleam for test fixtures
16. **`decode.optional_field(name, default, decode.string)` crashes on `null`** — `optional_field` only handles *missing* fields. When the field is present but `null`, `decode.string` runs on `null` and fails with `DecodeError("String", "Nil", [field_name])`. Fix: if the server can send `null`, use `Option(T)` in the shared type with `decode.optional_field(name, None, decode.optional(decode.string))`. Unwrap to display value in the client view, not in the shared decoder. Same applies to custom decoders like `money.decoder()`. Exception: decoders that handle null semantically (e.g., `note.decoder()` returns `empty()` for null).
