# Lustre

Frontend framework for building web apps in Gleam (Elm-inspired: model, update, view).

**Package:** [lustre on Hex](https://hex.pm/packages/lustre)  
**Docs:** [HexDocs](https://hexdocs.pm/lustre/)

## When to use

- Browser SPAs (single-page applications).
- Elm-style architecture: single model, update function for messages, view function for HTML. Works with JavaScript target.

## Entrypoints

- **lustre** — `lustre.simple(init, update, view)` for simple apps (model and message types). `lustre.application(init, update, view)` when you need effects (e.g. HTTP). `lustre.start(app, "#app", flags)` to mount the app.
- **lustre/element/html** — HTML elements: `html.div([], [])`, `html.button([], [html.text("Click")])`, etc.
- **lustre/attribute**, **lustre/event** — `attribute.class("name")`, `event.on_click(Msg)`.

## Pattern

- `init(flags)` returns initial model (and optionally effects).
- `update(model, msg)` returns new model (and optionally effects).
- `view(model)` returns `Element(Msg)`. Use `lustre_dev_tools` for dev server: `gleam run -m lustre/dev start`.
