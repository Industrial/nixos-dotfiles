# Gleam externals (FFI)

Use externals sparingly. Prefer pure Gleam; use FFI when you need runtime APIs (Erlang/Elixir on BEAM, JavaScript on JS target) or existing code in another language.

**When to use:** Runtime API (e.g. VM stats), or existing non-Gleam code that is impractical to reimplement in Gleam. Prefer an existing Gleam package when one exists.

**Reference:** [Gleam Externals](https://gleam.run/documentation/externals/).

## External types

- An external type has no constructors in Gleam. The compiler does not know its shape; it only knows the type exists. Values come from external functions.

## External functions

- Mark with `@external(erlang, "module", "function")` or `@external(javascript, "module", "function")` (syntax may vary by target).
- **Type annotations are required.** The compiler does not type-check non-Gleam code; incorrect annotations can cause runtime crashes.
- Multi-target: use `@external(erlang, ...)` and `@external(javascript, ...)` with different implementations, or external Gleam fallbacks for one target.

## Data mapping

- Gleam types map to Erlang/Elixir and JavaScript types (e.g. Gleam `List` ↔ Erlang list, Gleam `Result` ↔ `{ok, Val}` / `{error, E}`). See the externals docs for the full mapping so you pass correct types across the boundary.
