# FFI (Foreign Function Interface)

FFI should be used sparingly. Check for existing Gleam packages first. **FFI breaks type safety** — the compiler trusts your annotations without verification.

## When to Use FFI

- Accessing platform-specific APIs not available in Gleam packages
- Performance-critical code that benefits from native implementation
- Wrapping existing Erlang/Elixir/JavaScript libraries

## When NOT to Use FFI

- Standard operations covered by gleam_stdlib
- Things that "feel" easier in another language — often there's an idiomatic Gleam way
- As a first resort — search hexdocs.pm first

## Erlang FFI Syntax

```gleam
// In your Gleam file:
@external(erlang, "myapp_ffi", "do_thing")
pub fn do_thing(arg: String) -> Result(Int, Nil)

// In src/myapp_ffi.erl:
// -module(myapp_ffi).
// -export([do_thing/1]).
// do_thing(Arg) ->
//     case internal_logic(Arg) of
//         {ok, Value} -> {ok, Value};
//         error -> {error, nil}
//     end.
```

## JavaScript FFI Syntax

```gleam
// In your Gleam file:
@external(javascript, "./myapp_ffi.mjs", "doThing")
pub fn do_thing(arg: String) -> Result(Int, Nil)

// In src/myapp_ffi.mjs:
// import { Ok, Error } from "./gleam.mjs";
// export function doThing(arg) {
//   const result = internalLogic(arg);
//   return result !== null ? new Ok(result) : new Error(undefined);
// }
```

## FFI Best Practices

- **NEVER** name Erlang FFI modules the same as Gleam modules (causes infinite loops)
- Use `.mjs` extension for JavaScript FFI files (`.mts`, `.cts`, `.jsx`, `.tsx` also supported as native file extensions)
- Elixir modules need `Elixir.` prefix: `@external(erlang, "Elixir.Module", "func")`
- Write extensive tests for all FFI code
- Wrap FFI in validation layers when possible
- Keep FFI modules small and focused
- Document the expected types thoroughly
