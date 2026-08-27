# gleam_json

Encode and decode JSON in Gleam.

**Package:** [gleam_json on Hex](https://hex.pm/packages/gleam_json)  
**Docs:** [HexDocs](https://hexdocs.pm/gleam_json/)

## When to use

- Parsing JSON request/response bodies or config files.
- Producing JSON for APIs (encoding custom types to JSON strings).

## Entrypoints

- **gleam/json** — `json.parse(from: string, using: decoder)` returns `Result(Dynamic, DecodeError)`. Build decoders with `gleam/dynamic/decode`: `decode.field("name", decode.string)`, `decode.list(decode.int)`, etc., then `decode.success(MyType(...))`.
- **Encoding:** Build `json.Object` / `json.Array` / `json.String` etc. from your types, then `json.to_string(...)`.

## Pattern

Decoding: parse string → get `Dynamic` → run a `decode.Decoder(a)` built from `decode.*` combinators. Encoding: build JSON value from your type, then `json.to_string`.

## Encoding Example

```gleam
import myapp.{type Cat}
import gleam/json

pub fn cat_to_json(cat: Cat) -> String {
  json.object([
    #("name", json.string(cat.name)),
    #("lives", json.int(cat.lives)),
    #("flaws", json.null()),
    #("nicknames", json.array(cat.nicknames, of: json.string)),
  ])
  |> json.to_string
}
```

## Decoding Example

```gleam
import myapp.{Cat}
import gleam/json
import gleam/dynamic/decode

pub fn cat_from_json(json_string: String) -> Result(Cat, json.DecodeError) {
  let cat_decoder = {
    use name <- decode.field("name", decode.string)
    use lives <- decode.field("lives", decode.int)
    use nicknames <- decode.field("nicknames", decode.list(decode.string))
    decode.success(Cat(name:, lives:, nicknames:))
  }
  json.parse(from: json_string, using: cat_decoder)
}
```
