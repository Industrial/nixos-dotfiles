---
name: gleam-idiomatic
description: Guides writing and reviewing idiomatic Gleam code. Use when editing or creating Gleam modules (.gleam), implementing Gleam APIs, or when the user asks for Gleam style, Wisp (backend), Lustre (frontend), Gleam FFI, OTP, or JSON.
---

# Gleam idiomatic coding

Use this skill when working with Gleam code. Follow the workflow: load the required references, then load any optional references that match the task.

## When to use this skill

- Editing or creating `.gleam` files or Gleam projects.
- Implementing or reviewing Gleam APIs, libraries, or applications.
- User asks about Gleam style, Gleam backend (Wisp), frontend (Lustre), FFI, OTP, JSON, or JavaScript/browser interop.

## Must-read core references (required)

Before implementing or reviewing Gleam code, read and keep in context:

- [references/language-basics.md](references/language-basics.md) — modules, types, case, pipes, lists, naming.
- [references/style.md](references/style.md) — idiom rules (config records, no nested case, no closures in lib code, no abbreviations, imports, pipes over fluent).
- [references/stdlib.md](references/stdlib.md) — list/result/option/string highlights (e.g. `list.append`, no `list.concat`).

## Load when the task requires them

Read only when the user's task involves that area:

- **FFI / Erlang or JS interop** → [references/ffi.md](references/ffi.md)
- **Actors, supervisors, BEAM** → [references/otp.md](references/otp.md)
- **JSON encode/decode** → [references/gleam-json.md](references/gleam-json.md)
- **HTTP backend (handlers, middleware)** → [references/wisp.md](references/wisp.md)
- **Browser SPA (Elm-like UI)** → [references/lustre.md](references/lustre.md)
- **JavaScript types, promises (JS target)** → [references/gleam-javascript.md](references/gleam-javascript.md)
- **Browser or Node APIs (DOM, storage, etc.)** → [references/plinth.md](references/plinth.md)

## When unsure

Check the [Gleam Tour](https://tour.gleam.run/everything/) or official docs. Do not guess stdlib function names or import semantics.
