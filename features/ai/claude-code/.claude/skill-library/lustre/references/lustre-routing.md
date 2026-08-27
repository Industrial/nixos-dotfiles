# Routing with modem

modem intercepts browser navigation events (link clicks, popstate) and converts them into Lustre messages, enabling SPA routing without full page reloads.

## Setup in init

```gleam
import modem

fn init(_flags) -> #(Model, Effect(Msg)) {
  // Get the starting route from the current URL
  let route = case modem.initial_uri() {
    Ok(uri) -> route_from_uri(uri)
    Error(_) -> HomeRoute
  }
  // Subscribe to URL changes — modem calls your handler on every navigation
  let effects = modem.init(fn(uri) { OnRouteChange(route_from_uri(uri)) })
  #(Model(route: route, ..), effects)
}
```

## Navigating

```gleam
import gleam/option.{None, Some}

fn update(model, msg) {
  case msg {
    // Modem dispatches this on link clicks and back/forward
    OnRouteChange(route) ->
      #(Model(..model, route: route), effect.none())

    // Programmatic navigation — push adds a history entry
    NavigateTo(route) ->
      #(model, modem.push(route_to_path(route), None, None))

    // Replace doesn't add a history entry (good for redirects)
    RedirectTo(route) ->
      #(model, modem.replace(route_to_path(route), None, None))
  }
}
```

## Navigation Functions

```gleam
// Push new route onto browser history (no page reload)
modem.push(path: String, query: Option(String), fragment: Option(String)) -> Effect(msg)

// Replace current history entry (no new back-button entry)
modem.replace(path: String, query: Option(String), fragment: Option(String)) -> Effect(msg)

// Full page reload to a URI
modem.load(uri: uri.Uri) -> Effect(msg)

// Browser history navigation
modem.forward(steps: Int) -> Effect(msg)
modem.back(steps: Int) -> Effect(msg)
```

## Links in Views

Standard `<a>` tags with `href` work — modem intercepts same-origin link clicks automatically:

```gleam
// modem intercepts this click and dispatches OnRouteChange instead of a page reload
html.a([attribute.href("/products")], [html.text("Products")])

// External links are NOT intercepted (different origin)
html.a([attribute.href("https://example.com")], [html.text("External")])
```

## Route Module Pattern

Define a `Route` type and conversion functions:

```gleam
// route.gleam
import gleam/uri.{type Uri}
import gleam/string

pub type Route {
  HomeRoute
  ProductsRoute
  ProductDetailRoute(id: String)
  LoginRoute
  NotFoundRoute
}

/// Parse URI path segments into a Route
pub fn from_uri(uri: Uri) -> Route {
  case path_segments(uri.path) {
    [] -> HomeRoute
    ["products"] -> ProductsRoute
    ["products", id] -> ProductDetailRoute(id)
    ["login"] -> LoginRoute
    _ -> NotFoundRoute
  }
}

/// Convert Route to URL path
pub fn to_path(route: Route) -> String {
  case route {
    HomeRoute -> "/"
    ProductsRoute -> "/products"
    ProductDetailRoute(id) -> "/products/" <> id
    LoginRoute -> "/login"
    NotFoundRoute -> "/404"
  }
}

fn path_segments(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter(fn(s) { !string.is_empty(s) })
}
```

## Configuring Link Interception

```gleam
// Default: intercepts internal (same-origin) links only
modem.init(handler)

// Advanced: configure which links to intercept
modem.advanced(
  modem.Options(
    handle_internal_links: True,
    handle_external_links: False,  // set True to intercept cross-origin too
  ),
  handler,
)
```
