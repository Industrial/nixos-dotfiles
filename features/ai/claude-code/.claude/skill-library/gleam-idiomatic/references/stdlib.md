# Gleam standard library highlights

Key modules and functions. Full API: [gleam_stdlib HexDocs](https://hexdocs.pm/gleam_stdlib/).

## list (gleam/list)

- **Append lists:** `list.append(first, second)` — joins one list onto the end of another. There is **no** `list.concat`; use `list.append` or `list.flatten` for a list of lists.
- **Map / filter / fold:** `list.map(list, with: fn)`, `list.filter(list, keeping: predicate)`, `list.fold(over: list, from: initial, with: fn)`.
- **Other:** `list.reverse`, `list.length`, `list.first`, `list.rest`, `list.take`, `list.drop`, `list.prepend(to:, this:)`, `list.contains(any:)`, `list.find(in:, one_that:)`. Many functions use labeled arguments.

## result (gleam/result)

- `result.map(over:, with:)`, `result.then(over:, with:)`, `result.unwrap(over:, or:)`, `result.is_ok`, `result.is_error`.
- Use `result.try_recover` when you need the error value for fallback logic.

## option (gleam/option)

- `option.map(option, with: fn)`, `option.unwrap(option, or: default)`, `option.is_some`, `option.is_none`.

## string (gleam/string)

- `string.append(to:, suffix:)`, `string.concat(list_of_strings)`, `string.contains(does:, contain:)`, `string.drop_start(from:, up_to:)`, `string.drop_end(from:, up_to:)`, `string.reverse`, `string.length`, `string.split(on:)`.

## dict (gleam/dict)

- Maps: `dict.new()`, `dict.from_list([#("key", value), ...])`, `dict.get`, `dict.insert`, `dict.remove`.

## dynamic decode (gleam/dynamic/decode)

- Used with JSON and other dynamic data: build decoders with `decode.string`, `decode.int`, `decode.field("name", decoder)`, `decode.list(decoder)`, and `decode.success(Constructor(...))` for building typed values. See gleam_json for JSON parsing.
