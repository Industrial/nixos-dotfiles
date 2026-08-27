# Gleam Library Design Best Practices

This guide covers patterns for designing well-structured Gleam libraries, derived from studying Lustre and Lustre/UI as exemplary Gleam libraries.

## Core Principles

### 1. No IO in Library Core

Libraries should be pure - effects are data, the runtime executes them.

```gleam
// DON'T: Perform IO directly
pub fn save(data: Data) -> Result(Nil, Error) {
  file.write("config.json", encode(data))  // Side effect!
}

// DO: Return effects as data
pub fn save(data: Data) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    case file.write("config.json", encode(data)) {
      Ok(_) -> dispatch(SaveSucceeded)
      Error(e) -> dispatch(SaveFailed(e))
    }
  })
}

// BETTER: Accept a writer function from the caller
pub fn save(
  data: Data,
  writer: fn(String, String) -> Result(Nil, Error),
) -> Result(Nil, Error) {
  writer("config.json", encode(data))
}
```

### 2. No Environment Variables

Configuration should be explicit via function arguments.

```gleam
// DON'T: Read environment variables
pub fn connect() -> Client {
  let api_key = os.get_env("API_KEY") |> result.unwrap("")
  Client(api_key:)
}

// DO: Accept configuration as parameters
pub fn connect(config: Config) -> Client {
  Client(api_key: config.api_key)
}

// Or use a builder pattern
pub fn new() -> ClientBuilder {
  ClientBuilder(api_key: None, base_url: None)
}

pub fn with_api_key(builder: ClientBuilder, key: String) -> ClientBuilder {
  ClientBuilder(..builder, api_key: Some(key))
}
```

### 3. No Filesystem Access

Pure functions accept content as parameters rather than reading files.

```gleam
// DON'T: Read files internally
pub fn parse_config() -> Result(Config, Error) {
  let content = file.read("config.toml")
  parse(content)
}

// DO: Accept content as parameter
pub fn parse_config(content: String) -> Result(Config, Error) {
  parse(content)
}
```

### 4. Effects as Data

Follow Lustre's effect pattern - effects describe what to do, they don't do it.

```gleam
// Effect is a description of a side effect
pub type Effect(msg) {
  Effect(run: fn(fn(msg) -> Nil) -> Nil)
}

// Constructors return effect descriptions
pub fn fetch(url: String, handler: fn(Result) -> msg) -> Effect(msg) {
  Effect(fn(dispatch) {
    // The runtime will execute this
    let result = http.get(url)
    dispatch(handler(result))
  })
}

// No effect
pub fn none() -> Effect(msg) {
  Effect(fn(_) { Nil })
}

// Combine effects
pub fn batch(effects: List(Effect(msg))) -> Effect(msg) {
  Effect(fn(dispatch) {
    list.each(effects, fn(Effect(run)) { run(dispatch) })
  })
}
```

## Project Structure

### Directory Layout

```
my_library/
├── gleam.toml
├── README.md
├── CHANGELOG.md
├── LICENSE
├── src/
│   ├── my_library.gleam           # Public API, re-exports
│   └── my_library/
│       ├── internal/              # Hidden via internal_modules
│       │   ├── parser.gleam
│       │   └── validator.gleam
│       ├── types.gleam            # Public types
│       └── helpers.gleam          # Public utilities
├── test/
│   ├── unit/                      # Fast, isolated tests
│   ├── integration/               # Tests with real dependencies
│   ├── snapshot/                  # Birdie snapshot tests
│   └── benchmark/                 # Performance benchmarks
└── examples/
    ├── 01_hello_world/
    ├── 02_basic_usage/
    └── 03_advanced_patterns/
```

### gleam.toml Configuration

```toml
name = "my_library"
version = "1.0.0"
description = "A well-designed Gleam library"
licences = ["MIT"]
repository = { type = "github", user = "username", repo = "my_library" }

# CRITICAL: Hide implementation details
internal_modules = [
  "my_library/internal",
  "my_library/internal/*",
]

[dependencies]
gleam_stdlib = ">= 0.34.0 and < 2.0.0"

[dev-dependencies]
gleeunit = ">= 1.0.0 and < 2.0.0"
birdie = ">= 1.0.0 and < 2.0.0"
```

## Documentation Requirements

### Module Documentation

Use `////` for module-level documentation at the top of each public module:

```gleam
//// This module provides HTTP client functionality.
////
//// ## Overview
////
//// The client supports GET, POST, PUT, and DELETE requests with
//// automatic JSON encoding/decoding.
////
//// ## Example
////
//// ```gleam
//// import my_library/http
////
//// pub fn main() {
////   let client = http.new() |> http.with_base_url("https://api.example.com")
////   let response = http.get(client, "/users")
//// }
//// ```
////
//// ## Related Packages
////
//// - `gleam_http` - Low-level HTTP types
//// - `gleam_json` - JSON encoding/decoding
////

import gleam/result
// ... rest of module
```

### Function Documentation

Use `///` for function documentation with examples:

```gleam
/// Creates a new client with default configuration.
///
/// ## Example
///
/// ```gleam
/// let client = http.new()
/// ```
///
pub fn new() -> Client {
  Client(base_url: "", headers: [])
}

/// Sends a GET request to the specified path.
///
/// Returns `Ok(response)` on success or `Error(reason)` on failure.
///
/// ## Example
///
/// ```gleam
/// let client = http.new() |> http.with_base_url("https://api.example.com")
/// case http.get(client, "/users") {
///   Ok(response) -> handle_response(response)
///   Error(e) -> handle_error(e)
/// }
/// ```
///
pub fn get(client: Client, path: String) -> Result(Response, Error) {
  // implementation
}
```

### README Structure

```markdown
# my_library

Brief one-line description of what the library does.

[![Package Version](https://img.shields.io/hexpm/v/my_library)](https://hex.pm/packages/my_library)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/my_library/)

## Installation

```sh
gleam add my_library
```

## Quick Start

```gleam
import my_library

pub fn main() {
  // Minimal working example
}
```

## Philosophy

Explain the design decisions and constraints:
- Why effects are returned as data
- Why configuration is explicit
- Any other design principles

## Examples

See the `examples/` directory for complete working examples:
- `01_hello_world/` - Minimal setup
- `02_basic_usage/` - Common use cases
- `03_advanced_patterns/` - Complex scenarios

## Documentation

Full API documentation: https://hexdocs.pm/my_library/
```

### Examples Folder

Number examples by complexity, each should be standalone:

```
examples/
├── 01_hello_world/
│   ├── gleam.toml           # Points to parent library
│   ├── README.md            # What this example demonstrates
│   └── src/
│       └── hello.gleam
├── 02_json_parsing/
│   ├── gleam.toml
│   ├── README.md
│   └── src/
│       └── parsing.gleam
└── 03_error_handling/
    ├── gleam.toml
    ├── README.md
    └── src/
        └── errors.gleam
```

Each example's `gleam.toml`:

```toml
name = "example_hello_world"
version = "0.0.0"

[dependencies]
my_library = { path = "../.." }
```

## Testing Patterns

### Unit Tests with Gleeunit

```gleam
// test/unit/parser_test.gleam
import gleeunit
import gleeunit/should
import my_library/parser

pub fn main() {
  gleeunit.main()
}

pub fn parse_valid_input_test() {
  parser.parse("valid input")
  |> should.be_ok()
  |> should.equal(Expected(value: "valid input"))
}

pub fn parse_empty_input_returns_error_test() {
  parser.parse("")
  |> should.be_error()
  |> should.equal(EmptyInput)
}
```

### Snapshot Tests with Birdie

```gleam
// test/snapshot/output_test.gleam
import birdie
import my_library/renderer

pub fn render_simple_element_test() {
  renderer.render(Element("div", [], []))
  |> birdie.snap("render_simple_element")
}

pub fn render_nested_elements_test() {
  renderer.render(
    Element("div", [], [
      Element("span", [], [Text("Hello")]),
    ])
  )
  |> birdie.snap("render_nested_elements")
}
```

### Simulation Tests for UI (Lustre Pattern)

For libraries with UI components, use simulation testing (requires Lustre v5.2.0+):

```gleam
// test/integration/counter_test.gleam
import lustre/dev/query
import lustre/dev/simulate
import my_component/counter

pub fn increment_updates_count_test() {
  counter.app()
  |> simulate.start(Nil)
  |> simulate.click(on: query.element(query.test_id("inc-btn")))
  |> simulate.model()
  |> should.equal(Counter(count: 1))
}

pub fn decrement_below_zero_test() {
  counter.app()
  |> simulate.start(Nil)
  |> simulate.click(on: query.element(query.test_id("dec-btn")))
  |> simulate.model()
  |> fn(model) { model.count >= 0 }
  |> should.be_true()
}
```

See `frontend/lustre-testing.md` for full query/simulate API reference.

## API Wrapper Specifics

When wrapping external APIs (REST, GraphQL, etc.), follow these additional guidelines.

### CRITICAL: Request Schema from User

**Before writing any API wrapper code, ask the user for:**
- OpenAPI/Swagger specification
- JSON Schema for request/response types
- API documentation URL
- Example requests and responses

```
"To create an accurate API wrapper, I need the API schema.
Do you have an OpenAPI spec, JSON schema, or API documentation
I can reference?"
```

### Mock Objects from Schema

Generate mock objects directly from the schema for testing:

```gleam
// test/mocks/user_mock.gleam
pub fn user() -> User {
  User(
    id: "user_123",
    email: "test@example.com",
    name: "Test User",
    created_at: "2024-01-01T00:00:00Z",
  )
}

pub fn user_list() -> List(User) {
  [user(), User(..user(), id: "user_456", email: "other@example.com")]
}
```

### Endpoint Versioning

Support API versioning with distinct types:

```gleam
// src/my_api/v1/user.gleam
pub type User {
  User(id: String, name: String)
}

pub fn decoder() -> Decoder(User) {
  // v1 decoder
}

// src/my_api/v2/user.gleam
pub type User {
  User(id: String, first_name: String, last_name: String, email: String)
}

pub fn decoder() -> Decoder(User) {
  // v2 decoder
}
```

### Opaque Request/Response Types

Hide implementation details with opaque types:

```gleam
// Request type is opaque - users can't construct invalid requests
pub opaque type Request(body) {
  Request(
    method: Method,
    path: String,
    headers: List(#(String, String)),
    body: Option(body),
  )
}

// Only exposed constructors can create requests
pub fn get(path: String) -> Request(Nil) {
  Request(method: Get, path:, headers: [], body: None)
}

pub fn post(path: String, body: body) -> Request(body) {
  Request(method: Post, path:, headers: [], body: Some(body))
}

// Response is also opaque
pub opaque type Response(body) {
  Response(
    status: Int,
    headers: List(#(String, String)),
    body: body,
  )
}

// Accessors for reading response data
pub fn status(response: Response(body)) -> Int {
  response.status
}

pub fn body(response: Response(body)) -> body {
  response.body
}
```

### Test All Endpoints Against Mocks

```gleam
// test/integration/api_test.gleam
import my_api
import my_api/mock

pub fn get_user_test() {
  let mock_server = mock.server()
    |> mock.on_get("/users/123", mock.user())

  my_api.new()
  |> my_api.with_base_url(mock_server.url)
  |> my_api.get_user("123")
  |> should.be_ok()
  |> should.equal(mock.user())
}

pub fn create_user_test() {
  let mock_server = mock.server()
    |> mock.on_post("/users", fn(body) {
      mock.user_from_create_request(body)
    })

  my_api.new()
  |> my_api.with_base_url(mock_server.url)
  |> my_api.create_user(CreateUser(name: "Test", email: "test@example.com"))
  |> should.be_ok()
}
```

## Anti-Patterns to Avoid

### 1. Direct IO in Library Code

```gleam
// DON'T
pub fn load_config() -> Config {
  let content = file.read("config.json") |> result.unwrap("{}")
  json.decode(content, config_decoder()) |> result.unwrap(default_config())
}

// DO
pub fn parse_config(json_string: String) -> Result(Config, DecodeError) {
  json.decode(json_string, config_decoder())
}
```

### 2. Environment Variable Access

```gleam
// DON'T
pub fn api_client() -> Client {
  Client(key: envoy.get("API_KEY") |> result.unwrap(""))
}

// DO
pub fn api_client(key: String) -> Client {
  Client(key:)
}
```

### 3. Hidden Network Calls

```gleam
// DON'T
pub fn validate_email(email: String) -> Bool {
  // Hidden network call!
  http.get("https://validator.example.com/check?email=" <> email)
  |> result.is_ok()
}

// DO
pub fn validate_email_format(email: String) -> Bool {
  // Pure validation
  string.contains(email, "@") && string.contains(email, ".")
}

// Or return an effect
pub fn validate_email_remote(
  email: String,
  handler: fn(Result(Bool, Error)) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let result = http.get("https://validator.example.com/check?email=" <> email)
    dispatch(handler(result))
  })
}
```

### 4. Exposing Internal Types

```gleam
// DON'T: Internal implementation exposed
// gleam.toml has NO internal_modules

// src/my_lib/internal/state.gleam
pub type InternalState {
  InternalState(cache: Dict(String, Value), dirty: Bool)
}

// Users can depend on internal structure!

// DO: Hide internals
// gleam.toml:
// internal_modules = ["my_lib/internal", "my_lib/internal/*"]

// src/my_lib.gleam
pub opaque type State {
  State(internal: InternalState)
}
```

### 5. Non-Composable APIs

```gleam
// DON'T: Monolithic function with many parameters
pub fn render(
  content: String,
  bold: Bool,
  italic: Bool,
  size: Int,
  color: String,
  background: String,
) -> Element {
  // ...
}

// DO: Composable attribute pattern
pub fn text(attrs: List(Attribute), content: String) -> Element {
  // ...
}

pub fn bold() -> Attribute { /* ... */ }
pub fn italic() -> Attribute { /* ... */ }
pub fn size(n: Int) -> Attribute { /* ... */ }
pub fn color(c: String) -> Attribute { /* ... */ }

// Usage:
text([bold(), size(16), color("red")], "Hello")
```

## Pre-Publish Checklist

Before publishing to Hex, verify all items:

### Code Quality

- [ ] `gleam check` passes with no errors
- [ ] `gleam format` has been run (no formatting changes)
- [ ] No compiler warnings (unused imports, variables)
- [ ] All `Result` types are properly handled

### Purity Requirements

- [ ] No direct file system access in library code
- [ ] No environment variable reads
- [ ] No hidden network calls
- [ ] Effects returned as data, not executed
- [ ] All configuration via explicit parameters

### Documentation

- [ ] All public modules have `////` module docs
- [ ] All public functions have `///` doc comments
- [ ] Examples in doc comments are valid Gleam code
- [ ] README includes installation, quick start, philosophy
- [ ] CHANGELOG documents changes for this version

### Testing

- [ ] `gleam test` passes
- [ ] Unit tests cover public API
- [ ] Snapshot tests for output-generating functions
- [ ] Integration tests for complex workflows
- [ ] Edge cases tested (empty input, invalid data)

### Examples

- [ ] Each example compiles independently
- [ ] Examples are numbered by complexity
- [ ] Each example has a README explaining its purpose
- [ ] Examples demonstrate real use cases

### Configuration

- [ ] `internal_modules` configured in `gleam.toml`
- [ ] Version number updated appropriately
- [ ] Dependencies have appropriate version ranges
- [ ] Repository and documentation links are correct

### Final Verification

```bash
# Run all checks
gleam check && gleam format --check && gleam test

# Build documentation locally
gleam docs build

# Try installing in a fresh project
cd /tmp && mkdir test_install && cd test_install
gleam new test_app && cd test_app
gleam add my_library@local:../path/to/my_library
gleam check
```
