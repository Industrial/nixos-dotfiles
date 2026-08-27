# gleam_javascript

Work with JavaScript types and values from Gleam when compiling to the JavaScript target (e.g. promises, arrays, symbols).

**Package:** [gleam_javascript on Hex](https://hex.pm/packages/gleam_javascript)  
**Docs:** [HexDocs](https://hexdocs.pm/gleam_javascript/)

## When to use

- JavaScript target only: calling JS APIs, using promises, or using JS arrays instead of Gleam lists at the boundary.
- Interop with browser or Node APIs when you need types that mirror JS (e.g. `Promise`).

## Entrypoints

- **gleam/javascript/promise** — Create and await JavaScript promises from Gleam. Use `promise.await(...)` in Gleam to work with async JS; typically used with `use` or in effectful Lustre apps.
- **gleam/javascript/array** — Work with JavaScript arrays; convert to/from Gleam lists as needed at the boundary.
- **gleam/javascript/symbol** — JavaScript symbols if required by JS APIs.

## Notes

- Only relevant when the project target is `javascript` in `gleam.toml`. For browser DOM/storage/Node APIs, see also **plinth**, which provides Gleam bindings to many platform APIs.
