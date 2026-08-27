# Lustre Testing Patterns

Extended Radish-style patterns for Lustre frontend testing.

## Test app scaffolding (Radish pattern)

```gleam
fn init(_flags) {
  #(my_component.init(), effect.none())
}

fn test_update(_model, msg) {
  #(msg, effect.none())
}

fn test_app() {
  simulate.application(init, test_update, my_component.view)
  |> simulate.start(Nil)
}

fn app_with_state(state) {
  simulate.application(
    fn(_) { #(state, effect.none()) },
    test_update,
    my_component.view,
  )
  |> simulate.start(Nil)
}
```

## Testing effects (simulate discards effects, feed results manually)

```gleam
pub fn fetch_success_populates_list_test() {
  let model =
    test_app()
    |> simulate.message(FetchedOrders(Ok([order_fixture()])))
    |> simulate.model()
  model.orders |> list.length() |> should.equal(1)
}

pub fn fetch_error_sets_error_state_test() {
  let model =
    test_app()
    // The Msg carries a typed ErrorCode, never a stringly message
    |> simulate.message(FetchedOrders(Error(RequestTimedOut)))
    |> simulate.model()
  model.error |> should.equal(Some(RequestTimedOut))
}
```

## Multi-step interaction chains

```gleam
pub fn fill_form_and_submit_test() {
  let model =
    test_app()
    |> simulate.input(on: query.element(query.id("email")), value: "a@b.com")
    |> simulate.input(on: query.element(query.id("name")), value: "Alice")
    |> simulate.click(on: query.element(query.id("submit")))
    |> simulate.model()
  model.save |> should.equal(submit.SubmitSaving)
  model.form.email |> should.equal("a@b.com")
}
```

## Two-message trick (components with FFI effects)

When a component uses FFI to dispatch a CustomEvent (focus trap, value change, outside click), simulate only sees the Lustre message — not the FFI dispatch. Design tests to verify each mechanism independently.

**Pattern:** Component click returns `on_open_change(False)` (Lustre message) AND FFI dispatches a `radish-value-change` CustomEvent. In simulate, only the first fires.

```gleam
// Test 1: Lustre message path — click closes dropdown
pub fn click_item_closes_select_test() {
  let model =
    open_app()
    |> simulate.click(on: item_id("banana"))
    |> simulate.model()
  model.open |> should.equal(False)
}

// Test 2: CustomEvent path — manually dispatch the FFI event
pub fn value_change_event_updates_value_test() {
  let model =
    open_app()
    |> simulate.event(
      on: query.element(query.id("sel")),
      name: "radish-value-change",
      data: [#("detail", json.string("banana"))],
    )
    |> simulate.model()
  model.value |> should.equal("banana")
}
```

## Testing pure view helpers (skip full Model)

For pages with complex rendering logic, extract the view function as `pub fn` and test it directly — no need to construct the full page Model.

```gleam
pub fn draft_order_bar_width_is_10_percent_test() {
  let view = orders.order_progress(order.OrderDraft, language.Portuguese)
  query.find(
    in: view,
    matching: query.element(query.text("10%")),
  )
  |> should.be_ok
}
```

## Testing components with CustomEvent-based FFI

For components like rich text editors where FFI manages DOM state, test by manually dispatching the custom events that FFI would normally produce.

```gleam
pub fn content_change_updates_model_test() {
  let model =
    test_app()
    |> simulate.event(
      on: query.element(query.attribute("data-radish-rich-editor", "")),
      name: "radish-content-change",
      data: [#("detail", json.string("[{\"_type\":\"block\"}]"))],
    )
    |> simulate.model()
  model.content |> should.not_equal("")
}
```

## Query selector cheat sheet (behavioral selectors only)

| Use | Pattern |
|-----|---------|
| By ID | `query.id("my-id")` |
| By tag | `query.tag("button")` |
| By text | `query.text("Save")` |
| By attribute | `query.attribute("role", "dialog")` |
| By ARIA | `query.aria("expanded", "true")` |
| By data attr | `query.data("state", "open")` |
| Combined | `query.id("btn") \|> query.and(query.aria("disabled", "true"))` |
| **Avoid** | `query.class(...)`, `query.style(...)` |

## query.has vs query.find

- `query.has(in: view, matching: ...)` → returns `Bool` — use for existence checks
- `query.find(in: view, matching: query.element(...))` → returns `Result` — use when you need the element for further assertions
