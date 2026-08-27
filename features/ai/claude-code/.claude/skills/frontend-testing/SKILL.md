---
name: frontend-testing
description: Lustre frontend testing — model, update, and behavior. No styling tests unless explicitly requested.
---

# Frontend Testing

Lustre frontend testing — model, update, and behavior. No styling tests unless explicitly requested.

## Iron Law

Frontend tests verify **model, update, and behavior** — never CSS classes, Tailwind utilities, or visual styling. Styling tests are only written when the user explicitly requests them.

## What to test (always)

1. **Model state** — initial state, state after messages, derived state
2. **Update logic** — message → model transformation, effect triggers
3. **User interactions** — clicks, keyboard events, form input produce correct messages
4. **Conditional rendering** — elements appear/disappear based on model state
5. **ARIA and data attributes** — accessibility semantics (`aria-checked`, `data-state`)
6. **Text content** — labels, error messages, computed display values

## What to never test (unless explicitly asked)

1. CSS class names (`query.class("flex")`, `query.class("bg-brand-100")`)
2. Tailwind utilities or design tokens in class lists
3. Layout structure (grid columns, flex direction)
4. Color values, spacing, typography classes
5. Component wrapper styling (card backgrounds, border radius)

**Why:** CSS is a moving target. Tailwind classes change during design iterations. Tests coupled to class names break on every visual refresh without catching real bugs. Behavioral tests survive redesigns intact.

## Simulate limitations (know before you test)

1. **Effects are discarded** — `simulate` runs no effects. FFI calls, HTTP requests, and timers never fire. Feed effect results back manually with `simulate.message()`.
2. **`simulate.click()` bypasses browser disabled semantics** — a click on a `disabled` element still dispatches in simulate. Test disabled state by asserting the attribute is present, not by testing click behavior.
3. **CustomEvents from FFI don't fire** — if a component uses FFI to dispatch a CustomEvent (e.g., `radish-value-change`), simulate won't see it. Dispatch it manually with `simulate.event()`.

## Test structure (Radish pattern)

- **Level 1 — Unit:** Pure functions, no simulate. State constructors, helpers, formatters, pure view helpers.
- **Level 2 — Simulate:** Wire up a minimal Lustre app, dispatch events, assert on model via `simulate.model()`.
- **Level 2b — Attribute assertions:** Use `simulate.view()` + `query.has()`/`query.find()` to verify DOM attributes (ARIA, data-state, disabled) without a browser.

### Level 1 — Unit test examples

```gleam
// State construction
pub fn initial_order_form_has_empty_lines_test() {
  let model = order_form.init()
  model.lines |> should.equal([])
  model.save |> should.equal(submit.SubmitIdle)
}

// Update logic
pub fn add_line_appends_to_model_test() {
  let model = order_form.init()
  let #(updated, _effect) = order_form.update(model, order_form.AddLine)
  updated.lines |> list.length() |> should.equal(1)
}

// Formatters and derived state
pub fn total_sums_line_quantities_test() {
  let model = Model(lines: [Line(qty: 3), Line(qty: 7)])
  order_form.total(model) |> should.equal(10)
}

// Pure view helper — extract as pub fn, test without full Model
pub fn draft_order_shows_10_percent_progress_test() {
  let view = orders.order_progress(order.OrderDraft, language.Portuguese)
  query.find(in: view, matching: query.element(query.text("10%")))
  |> should.be_ok
}
```

### Level 2 — Simulate test examples

```gleam
// Click produces correct state change
pub fn click_submit_sets_submitting_test() {
  let model =
    test_app()
    |> simulate.click(on: query.element(query.id("submit-btn")))
    |> simulate.model()
  model.save |> should.equal(submit.SubmitSaving)
}

// Keyboard navigation
pub fn escape_closes_dropdown_test() {
  let model =
    open_app()
    |> simulate.event(
      on: query.element(query.id("dropdown")),
      name: "keydown",
      data: [#("key", json.string("Escape"))],
    )
    |> simulate.model()
  model.is_open |> should.equal(False)
}

// Conditional rendering via text/attribute, NOT class
pub fn error_message_shows_on_invalid_test() {
  let view =
    test_app()
    |> simulate.click(on: query.element(query.id("submit-btn")))
    |> simulate.view()
  query.has(in: view, matching: query.text("Email is required"))
  |> should.equal(True)
}

// ARIA semantics
pub fn disabled_button_has_aria_disabled_test() {
  let view =
    test_app()
    |> simulate.view()
  query.has(
    in: view,
    matching: query.id("submit-btn")
      |> query.and(query.aria("disabled", "true")),
  )
  |> should.equal(True)
}

// Disabled state — assert attribute, NOT click behavior
// (simulate.click bypasses browser disabled semantics)
pub fn disabled_checkbox_has_disabled_attribute_test() {
  let view =
    app_with_state(State(..defaults, disabled: True))
    |> simulate.view()
  query.has(
    in: view,
    matching: query.id("cb")
      |> query.and(query.attribute("disabled", "")),
  )
  |> should.equal(True)
}
```

## Anti-patterns (explicit violations)

```gleam
// BAD — testing CSS class
pub fn header_has_flex_layout_test() {
  let view = test_app() |> simulate.view()
  query.has(in: view, matching: query.class("flex"))  // VIOLATION
}

// BAD — testing Tailwind token
pub fn badge_has_brand_color_test() {
  let view = test_app() |> simulate.view()
  query.has(in: view, matching: query.class("bg-brand-100"))  // VIOLATION
}
```
