# Lustre Advanced Topics

## Hydration (Server + Client Rendering)

Hydration makes server-rendered HTML interactive.

### Process

1. Server renders HTML with `element.to_document_string()`
2. Embed model state as JSON in HTML
3. Client loads state from HTML
4. Start Lustre with hydrated state as flags

```gleam
// Server: Render HTML
let html = element.to_document_string(view(model))
let state_json = json.to_string(encode_model(model))
// Include state_json in a <script> tag

// Client: Hydrate
pub fn main() {
  let hydrated_state = case get_text_content("#state") {
    Ok(json) -> {
      let assert Ok(model) = json.parse(json, model_decoder())
      option.Some(model)
    }
    Error(_) -> option.None
  }

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", hydrated_state)
}

fn init(flags: option.Option(Model)) -> #(Model, Effect(Msg)) {
  case flags {
    option.Some(model) -> #(model, effect.none())  // Already hydrated
    option.None -> #(Loading, fetch_data())        // Need to fetch
  }
}
```

## Server Components

Server components run on the backend, sending DOM patches to a 10kB client runtime.

### Server Setup

```gleam
// Create component
pub fn component() -> App(_, Model, Msg) {
  lustre.simple(init, update, view)
}

// In WebSocket handler
fn init_socket(_) {
  let counter = counter.component()
  let assert Ok(runtime) = lustre.start_server_component(counter, Nil)

  let self = process.new_subject()
  let selector = process.new_selector() |> process.select(self)

  // Register for patches
  server_component.register_subject(self) |> lustre.send(to: runtime)

  #(SocketState(runtime:, self:), Some(selector))
}

fn loop_socket(state, message, connection) {
  case message {
    mist.Text(json) -> {
      // Decode and forward client messages
      case json.parse(json, server_component.runtime_message_decoder()) {
        Ok(msg) -> lustre.send(state.runtime, msg)
        Error(_) -> Nil
      }
      mist.continue(state)
    }
    mist.Custom(client_message) -> {
      // Send patches to client
      let json = server_component.client_message_to_json(client_message)
      let assert Ok(_) = mist.send_text_frame(connection, json.to_string(json))
      mist.continue(state)
    }
    mist.Closed | mist.Shutdown -> {
      lustre.shutdown() |> lustre.send(to: state.runtime)
      mist.stop()
    }
  }
}
```

### Client Setup

```gleam
// Serve the runtime script
html.script([
  attribute.type_("module"),
  attribute.src("/lustre/runtime.mjs"),
], "")

// Render server component element
server_component.element([
  server_component.route("/ws"),  // WebSocket URL
], [])
```

### Supervision

```gleam
// Supervised single component
lustre.supervised(app, start_args)

// Factory for dynamic components
lustre.factory(app)
```

## FFI in Lustre — When and How

Most Lustre work requires zero FFI. The framework provides pure Gleam APIs backed by internal FFI.

### Framework-Provided (Pure Gleam, No FFI Needed)

| Gleam function | What it does behind the scenes |
|---|---|
| `lustre.register(app, tag)` | `customElements.define()` |
| `lustre.start(app, selector, flags)` | Mounts SPA to DOM |
| `lustre.is_browser()` / `lustre.is_registered(name)` | Runtime target detection |
| `effect.before_paint(fn(dispatch, root))` | Schedule before browser paint (receives shadow root as `Dynamic`) |
| `effect.after_paint(fn(dispatch, root))` | Schedule after browser paint |
| `effect.provide(key, json)` | Set context on custom element |
| `component.set_pseudo_state(value)` / `remove_pseudo_state(value)` | CSS custom states via `ElementInternals` |
| `component.set_form_value(value)` / `clear_form_value()` | Form-associated element values |
| `event.emit(name, data)` | `CustomEvent` dispatch |
| `event.advanced(name, decoder)` | Event handler with `prevent_default`/`stop_propagation` |

### When FFI IS Appropriate

Lustre UI v5 shows the legitimate FFI cases for component authors. These are operations that have no pure-Gleam equivalent because they require direct DOM API access:

1. **Element queries and traversal** — `querySelector`, `closest`, `matches`, `contains`, `compareDocumentPosition`. Wrap in a Gleam module with opaque `HtmlElement` type and `Result`-returning functions.

2. **Focus management** — `element.focus()`, `document.activeElement`. Needed for keyboard navigation in complex components (accordion, tabs, menus).

3. **TreeWalker for keyboard navigation** — `document.createTreeWalker()` with shadow root piercing. Used for Home/End/Arrow key navigation across nested components. The Gleam wrapper uses a `Filter` type (`Accept | Skip | Reject`) to control traversal.

4. **Shadow DOM access** — `shadowRoot.host` to get the component element from inside a shadow root. Needed inside `effect.before_paint` callbacks where the root is received as `Dynamic`.

5. **Animations** — Measuring `scrollWidth`/`scrollHeight` and calling `element.animate()` for collapse/expand transitions.

6. **Event listeners** — `addEventListener` on specific elements (not handled by Lustre's virtual DOM diffing).

### Pattern for Writing Lustre FFIs

```
my_component/
  element.gleam      # Gleam module with typed functions
  element.ffi.mjs    # JavaScript FFI implementations
```

Rules:
- Wrap all DOM operations in a Gleam module with typed functions
- Use opaque types (e.g., `HtmlElement`) to prevent raw DOM manipulation
- Return `Result` for operations that can fail (querySelector, attribute access)
- Keep FFI functions minimal — one DOM operation per exported function
- Reference via `@external(javascript, "./module.ffi.mjs", "functionName")`

**Key rule:** Exhaust the framework's pure Gleam API first. Only write FFI for DOM operations the framework doesn't cover (element queries, focus, animations, measurement).

## Element Rendering

### String Output

```gleam
// Basic HTML string
element.to_string(my_element)

// Full document with DOCTYPE
element.to_document_string(my_element)

// For HTTP responses
element.to_document_string_tree(my_element)
|> bytes_tree.from_string_tree
```

### Memoization

For expensive computations:

```gleam
element.memo([element.ref(data)], fn() {
  expensive_view(data)
})
```

## Project Structure

Typical Lustre project layout:

```
src/
  app.gleam           # Main app (init, update, view)
  app.ffi.mjs         # JavaScript FFI bindings
  components/         # Reusable stateful components (rare)
    counter.gleam
  views/              # Reusable view functions (common)
    button.gleam
    card.gleam
  effects/            # Custom effects
    storage.gleam
  decoders/           # JSON/event decoders
    user.gleam
```
