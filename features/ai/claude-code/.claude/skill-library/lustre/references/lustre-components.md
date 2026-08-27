# Web Components (Lustre 5.x)

Lustre 5.x has a full Web Components system based on Custom Elements and Shadow DOM.

## Component Options

```gleam
lustre.component(init, update, view, [
  // React to HTML attribute changes (string values)
  component.on_attribute_change("count", count_decoder),

  // React to DOM property changes (any JS value, via JSON)
  component.on_property_change("items", items_decoder),

  // React to context from ancestor components
  component.on_context_change("theme", theme_decoder),

  // Adopt stylesheets from the document into shadow DOM
  component.adopt_styles(),

  // Delegate focus to shadow DOM contents
  component.delegates_focus(),

  // Use open shadow root (default is closed)
  component.open_shadow_root(),
])
```

## Component Registration

```gleam
pub fn register() -> Result(Nil, lustre.Error) {
  let app = lustre.component(init, update, view, [
    component.on_attribute_change("value", value_decoder),
    component.on_context_change("form", form_context_decoder),
    component.adopt_styles(),
  ])
  lustre.register(app, "my-input")
}
```

## Component Effects

Effects available only inside Web Components:

```gleam
// CSS custom states — style with :state(open) in CSS
component.set_pseudo_state("open")     // adds :state(open)
component.remove_pseudo_state("open")  // removes :state(open)

// Form-associated custom elements
component.set_form_value(json.string("selected-value"))
component.clear_form_value()
```

CSS usage:

```css
/* Target component states */
my-accordion:state(open) { ... }
my-accordion:not(:state(open)) { ... }
```

## Slots

Slots allow parent content to be projected into component shadow DOM:

```gleam
// In component's view — default slot (all unassigned children go here)
fn view(model) -> Element(Msg) {
  html.div([], [
    default_slot([], [
      // Fallback content shown when no children provided
      html.text("No content"),
    ]),
  ])
}

// Named slot — only children with matching slot attribute go here
fn view(model) -> Element(Msg) {
  html.div([], [
    named_slot("header", [], [html.text("Default header")]),
    default_slot([], [html.text("Default body")]),
    named_slot("footer", [], [html.text("Default footer")]),
  ])
}

// Parent assigns children to named slots
html.element("my-card", [], [
  html.div([slot("header")], [html.text("Card Title")]),
  html.p([], [html.text("Body goes to default slot")]),
  html.div([slot("footer")], [html.text("Card Footer")]),
])
```

## CSS Parts

Expose internal elements for external styling:

```gleam
// Component view — mark elements as styleable parts
fn view(model) -> Element(Msg) {
  html.div([part("container")], [
    html.button([part("trigger")], [html.text("Toggle")]),
    html.div([part("content")], [html.text(model.content)]),
  ])
}

// Re-export parts from nested components
html.element("inner-component", [exportparts(["trigger", "content"])], [])
```

CSS usage:

```css
my-accordion::part(trigger) { font-weight: bold; }
my-accordion::part(content) { padding: 1rem; }
```

## New Attributes (Lustre 5.x)

```gleam
// Mark element as non-interactive (greys out, removes from tab order)
attribute.inert(True)

// Set DOM properties (not HTML attributes) — only works in browser
attribute.property("value", json.string("controlled"))
attribute.property("checked", json.bool(True))

// ARIA attributes
attribute.aria_orientation("vertical")
attribute.aria_level(2)
```

**`attribute.property()` vs `attribute.attribute()`:**

- `attribute.attribute("value", "text")` sets HTML attribute (works everywhere, including SSR)
- `attribute.property("value", json.string("text"))` sets DOM property (browser only, needed for controlled inputs)
- For SSR compatibility: check `lustre.is_browser()` and fall back to `attribute.attribute()`
