# Lustre Core Architecture

Lustre is a web framework for Gleam following the Model-View-Update (MVU) architecture. It supports client-side SPAs, server components, web components, and server-side rendering.

## Model-View-Update Pattern

```gleam
// 1. Model: Single source of truth
type Model { ... }

// 2. Messages: Events from outside world
type Msg { ... }

// 3. Init: Create initial model
fn init(flags) -> #(Model, Effect(Msg))

// 4. Update: Pure state transitions
fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg))

// 5. View: Pure render function
fn view(model: Model) -> Element(Msg)
```

## Application Constructors

```gleam
// Simple app - NO effects, simpler signatures
// init: fn(flags) -> Model
// update: fn(Model, Msg) -> Model
lustre.simple(init, update, view)

// Full application - WITH effects
// init: fn(flags) -> #(Model, Effect(Msg))
// update: fn(Model, Msg) -> #(Model, Effect(Msg))
lustre.application(init, update, view)

// Web component (Lustre 5.x) - full options
lustre.component(init, update, view, options)

// Start the app
let assert Ok(_) = lustre.start(app, "#app", flags)
```

**Lustre 5.x utilities:**

```gleam
// Check if running in the browser (vs SSR or server)
lustre.is_browser()  // -> Bool

// Check if a custom element tag is already registered
lustre.is_registered("my-counter")  // -> Bool
```

## State Management

### Prefer Custom Types Over Records

```gleam
// DO: Use union types for distinct states
type Model {
  Loading
  Loaded(data: List(Item))
  Failed(error: String)
}

// DON'T: Avoid nullable fields in records
type Model {
  Model(loading: Bool, data: Option(List(Item)), error: Option(String))
}
```

### Message Naming Convention

Name messages using **Subject Verb Object** pattern:

```gleam
// DO: Clear origin and intent
type Msg {
  UserClickedSubmit
  UserUpdatedEmail(String)
  ApiReturnedUsers(Result(List(User), Error))
  TimerFired
}

// DON'T: Action-style naming
type Msg {
  Submit
  SetEmail(String)
  FetchUsers
}
```

## Side-Effect Management ("Dumb" Effects)

Effects (`effect.Effect(Msg)`) are executors of I/O (HTTP calls, DOM manipulation, timers). 

**Effects MUST NOT accept the `Model` as a parameter.**

```gleam
// BAD: Passing the whole Model encourages the effect to compute business logic
fn save_user_effect(model: Model) -> Effect(Msg) {
  // Wrong: Effect is deciding if data is valid
  case validate(model.form) {
    Ok(req) -> api.post(model.token, req, ...)
    Error(_) -> effect.none()
  }
}

// GOOD: Effect only accepts exact required primitives
fn save_user_effect(token: String, req: SaveUserRequest) -> Effect(Msg) {
  api.post(token, req, ...)
}
```

The `update` function is the ONLY brain in the application. It must extract, validate, and compute all necessary DTOs, and then pass only the final primitives into the effect function.

## State Accessor Helpers in the State Module (from #1183)

When a page state union type carries shared fields (e.g., `search: String` in all variants), provide accessor helper functions in the `state/<domain>.gleam` module rather than inlining the same multi-arm case expression at every call site.

```gleam
// DON'T: Inline pattern-match at every call site
let search = case model.products_page {
  ProductsLoading(search: s, ..) -> s
  ProductsLoaded(search: s, ..) -> s
  ProductsFailed(search: s, ..) -> s
  ProductsIdle -> ""
}
// ...repeated in view, update, and route handlers

// DO: Centralize structural knowledge in the state module
// state/products.gleam
pub fn current_search(page: ProductsPage) -> String {
  case page {
    ProductsLoading(search: s, ..) -> s
    ProductsLoaded(search: s, ..) -> s
    ProductsFailed(search: s, ..) -> s
    ProductsIdle -> ""
  }
}

// Call sites become one-liners:
let search = products_state.current_search(model.products_page)
```

Without these accessors, structural knowledge about the union type is duplicated across multiple files. A field rename or variant addition requires finding and updating every inlined case expression.
