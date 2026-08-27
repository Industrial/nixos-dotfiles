# Lustre UI Patterns

## The Prop Pattern (Controlled vs Uncontrolled)

Lustre UI v5 introduces the `Prop(a)` type for managing controlled vs uncontrolled component state:

```gleam
pub type Prop(a) {
  Prop(value: a, controlled: Bool, touched: Bool)
}
```

### States

- **`controlled: False, touched: False`** — Uncontrolled, accepts `default` attribute values. Initial state before user interaction.
- **`controlled: True`** — Parent owns the state. Events are emitted but the component does not update its own state internally.
- **`touched: True`** — User has interacted. No longer accepts default values (user's input takes precedence).

### How it works

```gleam
// Parent sets ATTRIBUTE "value" — treated as default (uncontrolled)
html.element("my-input", [
  attribute.attribute("value", "initial"),
], [])

// Parent sets PROPERTY "value" — takes control (controlled)
html.element("my-input", [
  attribute.property("value", json.string("controlled-value")),
], [])
```

Inside the component:

```gleam
fn update(model, msg) {
  case msg {
    // Attribute change: update if not controlled and not touched
    AttributeChanged(new_value) -> {
      case model.value.controlled || model.value.touched {
        True -> #(model, effect.none())  // Ignore — parent or user owns state
        False -> #(Model(..model, value: Prop(..model.value, value: new_value)), effect.none())
      }
    }

    // Property change: parent takes control
    PropertyChanged(new_value) -> {
      #(Model(..model, value: Prop(value: new_value, controlled: True, touched: model.value.touched)), effect.none())
    }

    // User interaction: mark as touched, emit event
    UserTyped(new_value) -> {
      let value = Prop(value: new_value, controlled: model.value.controlled, touched: True)
      #(Model(..model, value: value), event.emit("change", json.string(new_value)))
    }
  }
}
```

### Key rule

`attribute()` sets defaults (uncontrolled). `attribute.property()` takes control (controlled). Once a user interacts, `touched: True` prevents defaults from overwriting their input.

## Structural Opaque Types for Components

Lustre UI v5 uses opaque types to enforce correct component structure at compile time.

### Pattern

```gleam
// Opaque type ensures only valid items can be passed
pub opaque type AccordionItem(msg) {
  AccordionItem(
    value: String,
    attrs: List(Attribute(msg)),
    trigger: AccordionTrigger(msg),
    panel: AccordionPanel(msg),
  )
}

pub opaque type AccordionTrigger(msg) {
  AccordionTrigger(
    attrs: List(Attribute(msg)),
    children: List(Element(msg)),
  )
}

pub opaque type AccordionPanel(msg) {
  AccordionPanel(
    attrs: List(Attribute(msg)),
    children: List(Element(msg)),
  )
}

// Constructors accept attrs + children — NOT config builders
pub fn item(value: String, attrs: List(Attribute(msg)), trigger: AccordionTrigger(msg), panel: AccordionPanel(msg)) -> AccordionItem(msg) {
  AccordionItem(value:, attrs:, trigger:, panel:)
}

pub fn trigger(attrs: List(Attribute(msg)), children: List(Element(msg))) -> AccordionTrigger(msg) {
  AccordionTrigger(attrs:, children:)
}

pub fn panel(attrs: List(Attribute(msg)), children: List(Element(msg))) -> AccordionPanel(msg) {
  AccordionPanel(attrs:, children:)
}
```

### Usage

```gleam
// The compiler enforces correct structure:
accordion.root(state, [], [
  accordion.item("section-1", [],
    accordion.trigger([], [html.text("Section 1")]),
    accordion.panel([], [html.p([], [html.text("Content 1")])]),
  ),
  accordion.item("section-2", [],
    accordion.trigger([], [html.text("Section 2")]),
    accordion.panel([], [html.p([], [html.text("Content 2")])]),
  ),
])

// This WON'T compile — can't pass arbitrary elements where AccordionItem is expected:
accordion.root(state, [], [
  html.div([], [html.text("not an item")]),  // Type error!
])
```

### When to use structural opaques vs simple functions

| Component type | Pattern | Example |
|---|---|---|
| **Stateless, flat** | Simple functions (Pattern 1-5 from Composable UI) | button, card, alert, badge |
| **Stateful, structured** | Structural opaque types + Web Components | accordion, tabs, dialog, select |

## View Functions

### Prefer View Functions Over Components

```gleam
// DO: Simple reusable view functions
fn view_button(label: String, on_click: Msg) -> Element(Msg) {
  html.button([event.on_click(on_click)], [html.text(label)])
}

fn view_card(title: String, content: Element(msg)) -> Element(msg) {
  html.div([attribute.class("card")], [
    html.h2([], [html.text(title)]),
    content,
  ])
}

// Only use components when you need encapsulated state
```

### Keyed Lists

Use keyed elements for dynamic lists to prevent visual glitches. **Keys must be Strings.**

```gleam
// DO: Use keyed elements with String keys
keyed.ul([], list.map(items, fn(item) {
  let key = int.to_string(item.id)  // Key MUST be String
  #(key, html.li([], [html.text(item.name)]))
}))

// DON'T: Unkeyed dynamic lists cause diffing issues
html.ul([], list.map(items, fn(item) {
  html.li([], [html.text(item.name)])
}))
```

### Fragments

Group elements without a wrapper:

```gleam
element.fragment([
  html.h1([], [html.text("Title")]),
  html.p([], [html.text("Content")]),
])
```

## Controlled Inputs

Controlled inputs sync with your model on every keystroke. 

For robust form validation, use the "Parse, Don't Validate" pattern via a `FieldState(value, error)` wrapper rather than raw strings:

```gleam
// Using a field_state paradigm
html.input([
  attribute.value(field_state.raw(model.email)),     // Controlled raw string
  aria_invalid(field_state.has_error(model.email)),  // ARIA bindings
  event.on_input(UserUpdatedEmail),                  // Updates raw string
  event.on_blur(UserBlurredEmail),                   // Triggers validation
])
// Render error below input
html.div([class("error")], [text(field_state.error_text(model.email))])
```

For forms with many fields where validation is not required per-keystroke, consider uncontrolled inputs:

```gleam
html.form([event.on_submit(UserSubmittedForm)], [
  html.input([
    attribute.name("email"),
    attribute.default_value(""),
    // No on_input handler
  ]),
])
```

## Composable UI Patterns (lustre/ui)

The `lustre/ui` library demonstrates idiomatic patterns for building composable, reusable UI elements.

**These patterns (1-5) apply to stateless components** (button, card, alert, badge, input). For **stateful components** (accordion, tabs, dialog, select), use Web Components with the context system and structural opaque types documented above.

### Pattern 1: Element + of() for Semantic HTML

Provide a default element and an `of()` variant for custom HTML tags:

```gleam
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

// Default uses semantic HTML
pub fn card(
  attributes: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  of(html.article, attributes, children)
}

// of() allows any element constructor
pub fn of(
  element: fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg),
  attributes: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  element([attribute.class("my-card"), ..attributes], children)
}

// Usage:
card([], [...])                    // Renders as <article>
card.of(html.section, [], [...])   // Renders as <section>
card.of(html.div, [], [...])       // Renders as <div>
```

### Pattern 2: Sub-Element Functions for Composition

Expose composable child elements as module functions:

```gleam
// card.gleam
pub fn card(attrs, children) -> Element(msg) { ... }

pub fn header(
  attributes: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.header([attribute.class("card-header"), ..attributes], children)
}

pub fn content(
  attributes: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.main([attribute.class("card-content"), ..attributes], children)
}

pub fn footer(
  attributes: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.footer([attribute.class("card-footer"), ..attributes], children)
}

// Usage - components compose naturally:
card([], [
  card.header([], [html.h2([], [html.text("Title")])]),
  card.content([], [html.p([], [html.text("Body")])]),
  card.footer([], [button([], [html.text("OK")])]),
])
```

### Pattern 3: Attribute Functions for Variants

Use attribute functions instead of constructor parameters for styling:

```gleam
import lustre/attribute.{type Attribute, attribute}

// Style variants as attributes
pub fn solid() -> Attribute(msg) {
  attribute.class("btn-solid")
}

pub fn outline() -> Attribute(msg) {
  attribute.class("btn-outline")
}

// Size variants
pub fn small() -> Attribute(msg) {
  attribute.class("btn-sm")
}

pub fn large() -> Attribute(msg) {
  attribute.class("btn-lg")
}

// Usage - attributes compose with list concatenation:
button([btn.solid(), btn.large(), btn.pill(), event.on_click(Save)], [
  html.text("Save")
])
```

### Pattern 4: CSS Variables for Fine-Grained Control

Expose CSS custom properties for advanced customization:

```gleam
pub fn background(value: String) -> Attribute(msg) {
  attribute.style([#("--background", value)])
}

pub fn radius(value: String) -> Attribute(msg) {
  attribute.style([#("--radius", value)])
}

pub fn padding(x: String, y: String) -> Attribute(msg) {
  attribute.style([#("--padding-x", x), #("--padding-y", y)])
}

// Usage - override defaults per-instance:
card([
  card.background("#f5f5f5"),
  card.radius("1rem"),
  card.padding("2rem", "1rem"),
], [...])
```

### Pattern 5: Complete Composable Component Example

```gleam
// alert.gleam - Full composable component
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

pub fn alert(
  attributes: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  of(html.div, [attribute("role", "alert"), ..attributes], children)
}

pub fn of(
  element: fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg),
  attributes: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  element([attribute.class("alert"), ..attributes], children)
}

// Sub-elements
pub fn indicator(attrs, children) -> Element(msg) {
  html.span([attribute.class("alert-indicator"), ..attrs], children)
}

pub fn title(attrs, children) -> Element(msg) {
  html.strong([attribute.class("alert-title"), ..attrs], children)
}

pub fn content(attrs, children) -> Element(msg) {
  html.div([attribute.class("alert-content"), ..attrs], children)
}

// Semantic variants
pub fn info() -> Attribute(msg) { attribute.class("alert-info") }
pub fn success() -> Attribute(msg) { attribute.class("alert-success") }
pub fn warning() -> Attribute(msg) { attribute.class("alert-warning") }
pub fn danger() -> Attribute(msg) { attribute.class("alert-danger") }

// Usage:
alert([alert.danger()], [
  alert.indicator([], [icon.warning([])]),
  alert.title([], [html.text("Error")]),
  alert.content([], [html.text("Something went wrong.")]),
])
```

### Benefits of These Patterns

1. **Semantic HTML** - Default to proper elements (`<article>`, `<header>`, `<main>`)
2. **Flexible** - `of()` allows any HTML element when needed
3. **Composable** - Sub-elements compose naturally as children
4. **Type-safe** - Gleam's type system ensures valid composition
5. **Customizable** - CSS variables allow per-instance overrides
6. **No inheritance** - Pure functions, no class hierarchies
7. **Tree-shakeable** - Only import what you use

---

## Sprout Table Component — `table.body()` with `optimist.from()`

**Added:** 2026-03-08 — from #1601/#1607/#1608 migrations

The `sprout/table` component provides typed cell helpers (`text_cell`, `badge_cell`, `timestamp_cell`, `actions_cell`, etc.). The `table.body()` function takes `Optimistic(List(a))` — callers must `import optimist`.

**DON'T — raw keyed.tbody with manual row classes:**
```gleam
keyed.tbody([], list.map(items, fn(item) {
  #(item.id, html.tr([class("border-t border-[var(--border-default)]")], [
    html.td([class("py-3 pr-4 text-sm")], [text(item.email)]),
    html.td([class("py-3 text-right")], [action_button(item)]),
  ]))
}))
```

**DO — sprout/table with optimist.from() for static resolved lists:**
```gleam
import optimist
import sprout/table

table.root([], [
  table.header([], [
    table.row([], [
      table.head([], [text("Email")]),
      table.head([], [text("Actions")]),
    ]),
  ]),
  table.body([], optimist.from(items), fn(item) {
    table.row([], [
      table.text_cell([], item.email),
      table.actions_cell([], [revoke_button(item)]),
    ])
  }),
])
```

**Key rules:**
- `optimist.from(list)` wraps a resolved list — no optimistic features, no pending opacity.
- `table.body()` keys rows by **integer index** (`list.index_map`), not entity ID. Safe for read-only display lists; use `keyed.tbody` directly if rows can reorder while live.
- For optimistic-add items with no server ID yet (`id == ""`), the correct key is `item.id <> item.title` — stable for confirmed items, unique for pending-add items. Using `item.id` alone causes all pending-add items to share the same key, breaking Lustre's diffing.
- `actions_cell` already wraps children in `flex items-center justify-end gap-1`. Do NOT add an extra flex div inside it — pass action elements directly as siblings.
- `optimist` is vendored at `shared/lib/sprout/src/optimist.gleam` (top-level module, not `sprout/optimist`). Import as `import optimist`.
