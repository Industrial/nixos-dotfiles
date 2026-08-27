# Common Lustre Gotchas

## 1. Recursive Update Functions

```gleam
// DON'T: Recursive message dispatching
fn update(model, msg) {
  case msg {
    Save -> {
      let new_model = ...
      update(new_model, Validate)  // Anti-pattern!
    }
  }
}

// DO: Extract shared logic into functions
fn update(model, msg) {
  case msg {
    Save -> {
      let validated = validate(model)
      #(save(validated), effect.none())
    }
  }
}
```

## 2. Performing Side Effects in Update

```gleam
// DON'T: Side effects in update
fn update(model, msg) {
  let _ = http.get(url)  // Side effect!
  #(model, effect.none())
}

// DO: Return effects
fn update(model, msg) {
  #(model, rsvp.get(url, handler))
}
```

## 3. Missing Keys on Dynamic Lists

```gleam
// DON'T: Unkeyed lists
html.ul([], list.map(items, view_item))

// DO: Use keyed elements (keys must be Strings!)
keyed.ul([], list.map(items, fn(item) {
  #(int.to_string(item.id), view_item(item))
}))
```

## 4. Mixing Controlled and Uncontrolled Patterns

```gleam
// DON'T: Set value without handling changes (stuck input)
html.input([
  attribute.value(model.name),
  // Missing on_input handler - input appears frozen!
])

// DON'T: Uncontrolled with dynamic default (ignored after mount)
html.input([
  attribute.default_value(model.name),  // Only used on first render
])

// DO: Fully controlled
html.input([
  attribute.value(model.name),
  event.on_input(UserUpdatedName),
])

// DO: Fully uncontrolled (browser manages state)
html.input([
  attribute.name("name"),
  attribute.default_value(initial_value),
])
```

## 5. Forgetting to Shutdown Server Components

```gleam
// DON'T: Memory leak
fn close_socket(state) {
  Nil  // Component keeps running!
}

// DO: Clean up
fn close_socket(state) {
  lustre.shutdown() |> lustre.send(to: state.runtime)
}
```

## 6. Stateful Component Overuse

```gleam
// DON'T: Component for simple display
let component = lustre.component(...)  // Overkill!

// DO: Use view functions
fn view_user_card(user: User) -> Element(msg) {
  html.div([], [html.text(user.name)])
}
```

## 7. Effect Timing Issues

```gleam
// DON'T: DOM query in effect.from (runs BEFORE view!)
effect.from(fn(dispatch) {
  let el = document.get_element_by_id("new-element")
  // ALWAYS nil - view hasn't rendered yet!
})

// DO: Use before_paint for DOM operations after render
effect.before_paint(fn(dispatch, root) {
  let el = document.get_element_by_id("new-element")
  // Element exists - view has rendered
})

// DO: Use after_paint for focus, scroll, animations
effect.after_paint(fn(dispatch, root) {
  focus_element("input-field")
})
```

## 8. Including Non-Serializable Event Data (Server Components)

```gleam
// DON'T: Assume event properties are available
event.on("click", fn(event) {
  // event.target.id won't work in server components
})

// DO: Explicitly include properties
html.button([
  server_component.include(event.on("click", handler), ["target.id"]),
], [...])
```

## 9. before_paint Receives Dynamic, Not a Typed Element

```gleam
// DON'T: Assume root is typed
effect.before_paint(fn(dispatch, root) {
  root.querySelector(".item")  // Won't compile — root is Dynamic
})

// DO: Use FFI-backed decoder for shadow root operations
effect.before_paint(fn(dispatch, root) {
  case element.from_dynamic(root) {
    Ok(el) -> element.query_selector(el, ".item")
    Error(_) -> Nil
  }
})
```

## 10. attribute.property() Doesn't Work in SSR

```gleam
// DON'T: Use property() unconditionally
html.input([attribute.property("value", json.string(model.value))])

// DO: Check runtime and fall back
html.input([
  case lustre.is_browser() {
    True -> attribute.property("value", json.string(model.value))
    False -> attribute.attribute("value", model.value)
  },
  event.on_input(UserTyped),
])
```

## 11. on_attribute_change Fires on Initial Render

```gleam
// DON'T: Assume attribute change means user action
fn update(model, msg) {
  case msg {
    ValueChanged(v) -> #(Model(..model, value: v), do_expensive_work())
    // Fires on mount too! Wastes resources.
  }
}

// DO: Guard with Prop state
fn update(model, msg) {
  case msg {
    ValueChanged(v) -> {
      case model.value.controlled || model.value.touched {
        True -> #(model, effect.none())  // Already managed
        False -> #(Model(..model, value: Prop(..model.value, value: v)), effect.none())
      }
    }
  }
}
```

## 12. Don't Set Component-Managed ARIA Attributes

```gleam
// DON'T: Manually set ARIA that the component manages
accordion.trigger([
  attribute.attribute("role", "button"),         // Component sets this
  attribute.attribute("aria-expanded", "true"),  // Component manages this
  attribute.attribute("aria-controls", "panel"), // Component sets this
], [html.text("Toggle")])

// DO: Let the component handle its own ARIA
accordion.trigger([], [html.text("Toggle")])
// The component internally sets role, aria-expanded, aria-controls, aria-selected
```

## 13. event.debounce on Controlled Inputs

`event.debounce` wrapping `on_input` on a controlled input delays the model update. During the delay, the VDOM still holds the stale value, and the diff resets the DOM input to match — causing typed characters to vanish.

```gleam
// DON'T: debounce a controlled input's on_input
html.input([
  attribute.value(model.query),
  event.debounce(event.on_input(UserTypedSearch), 300),
  // User types "abc" → model still "" after 0ms → VDOM diff resets input to ""
])

// DO: guard in update instead
html.input([
  attribute.value(model.query),
  event.on_input(UserTypedSearch),
])

fn update(model, msg) {
  case msg {
    UserTypedSearch(text) ->
      case string.length(text) >= 2 {
        True -> #(Model(..model, query: text), search_effect(text))
        False -> #(Model(..model, query: text), effect.none())
      }
  }
}
```

## 14. Blur vs Click Race in Dropdowns

`on("blur")` fires before `on_click` (event order: mousedown → blur → mouseup → click). In combobox/autocomplete dropdowns, blur closes the dropdown before the click on a result item registers.

```gleam
// DON'T: use on_click on dropdown items with blur-to-close
html.button([event.on_click(UserSelectedResult(item))], [...])

// DO: use mousedown + prevent_default (keeps focus on input, no blur fires)
html.button([
  event.on("mousedown", {
    use <- decode.success
    UserSelectedResult(item)
  }) |> event.prevent_default,
], [...])
```

## 15. FFI File Naming Collision

Gleam compiles `foo.gleam` → `foo.mjs` in the build output. If you create a native JS FFI file with the same base name (e.g., `date_ffi.mjs` alongside `date_ffi.gleam`), the build output collides.

```gleam
// DON'T: name FFI file same as Gleam module
// date_ffi.gleam + date_ffi.mjs → collision in build/

// DO: suffix native JS files with _js
// date_ffi.gleam + date_ffi_js.mjs → no collision
@external(javascript, "./date_ffi_js.mjs", "formatDate")
pub fn format_date(iso: String) -> String
```

## 16. CSS Class Construction from Server Data

Never interpolate server-provided values into CSS class names. An attacker can inject arbitrary classes.

```gleam
// DON'T: interpolate server value
fn status_class(status: String) -> String {
  "badge--" <> status  // If status = "x onclick=alert(1)", classes are corrupted
}

// DO: closed case with hardcoded literals
fn status_class(status: OrderStatus) -> String {
  case status {
    Pending -> "badge--pending"
    Shipped -> "badge--shipped"
    Delivered -> "badge--delivered"
  }
}
```
