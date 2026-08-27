# Lustre Frontend Testing (query + simulate)

> Requires Lustre v5.2.0+. Import `lustre/dev/query` and `lustre/dev/simulate`.

## lustre/dev/query — Locating Elements

Query lets you find elements in a rendered `Element` tree without CSS selectors.

### Selectors (match a single element)

```gleam
query.tag("button")                        // by tag name
query.id("submit-btn")                     // by id attribute
query.class("active")                      // by class name
query.attribute("disabled", "true")        // by any attribute
query.data("role", "dialog")               // by data-* attribute
query.test_id("login-form")               // shorthand for data("test-id", _)
query.aria("label", "Close")              // by aria-* attribute
query.text("Submit")                       // by text content
query.style("display", "none")            // by inline style
query.namespaced("http://www.w3.org/2000/svg", "circle")  // namespaced element
```

### Combining selectors

```gleam
// Match a button with class "primary"
query.and(query.tag("button"), query.class("primary"))
```

### Building queries (tree traversal)

```gleam
query.element(selector)                    // match anywhere in tree
query.child(parent_query, selector)        // direct child only
query.descendant(parent_query, selector)   // any depth below parent
```

### Running queries

```gleam
query.find(in: view, query: q)        // -> Result(Element, Nil)
query.find_all(in: view, query: q)    // -> List(Element)
query.matches(element, selector)      // -> Bool (element matches?)
query.has(element, selector)          // -> Bool (any descendant matches?)
```

### Debugging

```gleam
query.to_readable_string(q)  // human-readable query description
```

## lustre/dev/simulate — Running Apps Without a Browser

Simulate constructs and runs a Lustre app in-memory. Effects are **discarded** (not executed).

### Constructing an app

```gleam
// For apps without effects
simulate.simple(init, update, view)

// For apps with effects (effects are discarded during simulation)
simulate.application(init, update, view)
```

### Starting and interacting

```gleam
simulate.start(app, flags)                         // -> Simulation
simulate.message(sim, msg)                          // dispatch a message directly
simulate.click(sim, on: query.element(selector))    // simulate click event
simulate.input(sim, on: query.element(selector), value: "text")  // simulate input
simulate.submit(sim, on: query.element(selector), fields: [#("email", "a@b.c")])
simulate.event(sim, on: query, name: "focus", data: [])  // arbitrary DOM event
simulate.problem(sim, name: "network", message: "timeout")  // inject a Problem
```

### Inspecting state

```gleam
simulate.model(sim)    // -> model (current state)
simulate.view(sim)     // -> Element(msg) (current rendered view)
simulate.history(sim)  // -> List(Event(msg)) (reverse-chronological)
```

### Event type

```gleam
pub type Event(msg) {
  Dispatch(message: msg)                                  // from simulate.message()
  Event(target: query.Query, name: String, data: Json)    // from click/input/event
  Problem(name: String, message: String)                  // from simulate.problem()
}
```

## Testing Patterns

### Pattern 1: Mark elements with test IDs

```gleam
// In your view
html.button([attribute.data("test-id", "inc-btn")], [html.text("+")])

// In your test — stable selector that won't break on styling changes
let btn = query.element(query.test_id("inc-btn"))
```

### Pattern 2: Pipe-based simulation chains

```gleam
pub fn increment_updates_count_test() {
  counter.app()
  |> simulate.start(Nil)
  |> simulate.click(on: query.element(query.test_id("inc-btn")))
  |> simulate.click(on: query.element(query.test_id("inc-btn")))
  |> simulate.model()
  |> should.equal(Counter(count: 2))
}
```

### Pattern 3: Snapshot testing with birdie

```gleam
pub fn renders_initial_view_test() {
  counter.app()
  |> simulate.start(Nil)
  |> simulate.view()
  |> element.to_readable_string()
  |> birdie.snap("counter_initial_view")
}
```

### Pattern 4: Querying the view subtree

```gleam
pub fn shows_error_message_on_failure_test() {
  let sim =
    my_app.app()
    |> simulate.start(Nil)
    |> simulate.problem("fetch", "404 Not Found")

  let error_query = query.element(query.test_id("error-msg"))

  sim
  |> simulate.view()
  |> query.find(error_query)
  |> should.be_ok()
}
```

### Pattern 5: Model assertions after interaction

```gleam
pub fn form_submit_captures_fields_test() {
  let model =
    login.app()
    |> simulate.start(Nil)
    |> simulate.input(
      on: query.element(query.test_id("email-input")),
      value: "user@example.com",
    )
    |> simulate.submit(
      on: query.element(query.test_id("login-form")),
      fields: [#("email", "user@example.com")],
    )
    |> simulate.model()

  model.submitted |> should.be_true()
  model.email |> should.equal("user@example.com")
}
```

### Pattern 6: Error path testing

```gleam
pub fn missing_target_logs_problem_test() {
  // Clicking a non-existent target doesn't crash — it logs a Problem
  let history =
    counter.app()
    |> simulate.start(Nil)
    |> simulate.click(on: query.element(query.test_id("nonexistent")))
    |> simulate.history()

  // History is reverse-chronological, most recent first
  case history {
    [simulate.Problem(name: _, message: _), ..] -> Nil
    _ -> panic as "expected a Problem event"
  }
}
```

## Key Caveats

- **Effects are discarded** — `simulate.application` accepts effect-returning init/update but never executes them. Use `simulate.message` or `simulate.problem` to manually feed results that would come from effects.
- **Missing targets log Problems** — clicking/inputting on a query that matches nothing doesn't crash; it appends a `Problem` event to history.
- **History is reverse-chronological** — most recent event is `list.first`.
- **Requires Lustre v5.2.0+** — the `lustre/dev/query` and `lustre/dev/simulate` modules were added in v5.2.0.
