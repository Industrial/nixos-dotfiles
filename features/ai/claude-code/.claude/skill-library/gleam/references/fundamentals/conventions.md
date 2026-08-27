# Official Gleam Conventions, Patterns & Anti-patterns

Source: https://gleam.run/documentation/conventions-patterns-and-anti-patterns

---

## Conventions (Always Follow)

### C1. Qualified Imports

**Severity:** P3 — Convention

Always use qualified syntax when referencing functions and constants from other modules. Types and record constructors may use unqualified imports when readability remains clear.

**Detection:** Grep for `import .* \.{` and check if functions/constants are imported unqualified.

```gleam
// Good
import gleam/list
import gleam/string

pub fn reverse(input: String) -> String {
  input
  |> string.to_graphemes
  |> list.reverse
  |> string.concat
}

// Bad — unqualified function imports
import gleam/list.{reverse}
import gleam/string.{to_graphemes, concat}

pub fn reverse(input: String) -> String {
  input
  |> to_graphemes
  |> reverse
  |> concat
}
```

**Acceptable unqualified imports:** Types (`type Option`, `type Result`), record constructors (`Some`, `None`, `Ok`, `Error`).

### C2. Type Annotations on All Module Functions

**Severity:** P2 — Maintainability

Every module function requires explicit type annotations for parameters AND return values.

**Detection:** Grep for `pub fn` or `fn` at module level. Check that all parameters have `: Type` and the signature has `-> ReturnType`.

```gleam
// Good
fn calculate_total(amounts: List(Int), service_charge: Int) -> Int {
  int.sum(amounts) * service_charge
}

// Bad — missing all annotations
fn calculate_total(amounts, service_charge) {
  int.sum(amounts) * service_charge
}

// Bad — missing return annotation
fn calculate_total(amounts: List(Int), service_charge: Int) {
  int.sum(amounts) * service_charge
}
```

### C3. Result for Fallible Functions

**Severity:** P1 — Architecture

Functions that can succeed or fail must return `Result` types. Gleam uses Result, not Option, for fallible operations. When no additional failure information exists, use `Result(a, Nil)`.

Libraries must never panic. Panicking may be appropriate only in application code.

> See `error-handling.md` for full error handling patterns.

```gleam
// Good
pub fn first(list: List(a)) -> Result(a, Nil) {
  case list {
    [item, ..] -> Ok(item)
    _ -> Error(Nil)
  }
}

// Bad — returns Option
pub fn first(list: List(a)) -> option.Option(a) {
  case list {
    [item, ..] -> option.Some(item)
    _ -> option.None
  }
}

// Bad — panics on failure
pub fn first(list: List(a)) -> a {
  case list {
    [item, ..] -> item
    _ -> panic as "cannot get first of empty list"
  }
}
```

### C4. Singular Module Names

**Severity:** P3 — Convention

Module names must be singular. This applies to all path segments.

> Also covered in `type-design.md`.

```gleam
// Good
import app/user
import app/payment/invoice

// Bad
import app/users
import app/payments/invoice
```

### C5. Acronyms as Single Words

**Severity:** P3 — Convention

Write acronyms as complete words in naming. Treat them as a single word, not individual letters.

**Detection:** Grep for `JSON`, `SQL`, `HTTP`, `URL`, `HTML`, `CSS`, `API`, `XML`, `UUID` in type names, variable names, and function names (all-caps form is wrong).

```gleam
// Good
let json: Json = build_json()

// Bad
let j_s_o_n: JSON = build_j_s_o_n()
```

**In practice:** `type JsonError`, not `type JSONError`. `fn parse_html`, not `fn parse_h_t_m_l`. `type SqlQuery`, not `type SQLQuery`.

### C6. Conversion Function Naming

**Severity:** P3 — Convention

Use the `x_to_y` pattern for type conversion functions. If the module name matches the type name, omit the type from the function name. Include format or encoding names when relevant.

```gleam
// Good — explicit conversion
pub fn json_to_string(data: Json) -> String

// Bad — other naming styles
pub fn json_into_string(data: Json) -> String
pub fn json_as_string(data: Json) -> String
pub fn string_of_json(data: Json) -> String

// Good — module matches type, omit type name
// In identifier.gleam:
pub fn to_string(id: Identifier) -> String

// Bad — redundant with module name
pub fn identifier_to_string(id: Identifier) -> String

// Good — specific format in name
pub fn date_to_rfc3339(date: Date) -> String

// Bad — too generic when format matters
pub fn date_to_string(date: Date) -> String

// Good — descriptive verb when conversion is a well-known operation
pub fn round(data: Float) -> Int

// Bad — mechanical naming
pub fn float_to_int(data: Float) -> Int
```

### C7. Fallible Function Naming

**Severity:** P3 — Convention

Name result-returning functions descriptively based on domain operations. The `try_` prefix should only be used for result-handling variants of existing functions when no domain-specific name applies.

```gleam
// Good — domain-specific names
pub fn parse_json(input: String) -> Result(Json, ParseError)
pub fn enqueue(job: BackgroundJob) -> Result(Nil, EnqueueError)

// Good — try_ prefix for result variant of existing function
pub fn map(list: List(a), f: fn(a) -> b) -> List(b)
pub fn try_map(
  list: List(a),
  f: fn(a) -> Result(b, e),
) -> Result(List(b), e)

// Bad — abstract/category-theory naming
pub fn monadic_bind(
  list: List(a),
  f: fn(a) -> Result(b, e),
) -> Result(List(b), e)
```

### C8. Use Core Libraries

**Severity:** P3 — Convention

Depend on Gleam's maintained core libraries to create a shared foundation. Do not replicate their functionality.

Core libraries: `gleam_stdlib`, `gleam_time`, `gleam_http`, `gleam_erlang`, `gleam_otp`, `gleam_javascript`.

### C9. Tool Config in gleam.toml

**Severity:** P3 — Convention

Development tool configuration should reside in `gleam.toml` under `[tools.$TOOL_NAME]` keys. Never create separate config files.

```toml
name = "thingy"
version = "1.0.0"

[dependencies]
gleam_stdlib = ">= 1.0.0 and < 2.0.0"

[javascript]
source_maps = true

[tools.lustre.dev]
host = "0.0.0.0"

[tools.lustre.build]
minify = true
outdir = "../server/priv/static"
```

### C10. Correct Source Directories

**Severity:** P3 — Convention

- `src/` — application/library code, imports from dependencies and src/
- `test/` — testing code, imports from any directory
- `dev/` — development helpers, imports from any directory

---

## Patterns (Apply When Beneficial)

### P1. Descriptive Error Types

**Severity:** P2 — Maintainability

Error types should describe domain-specific failure states with supporting detail. Include lower-level errors as fields when relevant to context.

> See `error-handling.md` for comprehensive error handling patterns.

```gleam
// Good — descriptive with context
pub type NoteBookError {
  NoteAlreadyExists(path: String)
  NoteCouldNotBeCreated(path: String, reason: simplifile.FileError)
  NoteCouldNotBeRead(path: String, reason: simplifile.FileError)
  NoteInvalidFrontmatter(path: String, reason: tom.ParseError)
}

// Bad — no context
pub type NotesError {
  NoteAlreadyExists
  NoteCouldNotBeCreated
  NoteCouldNotBeRead
  NoteInvalidFrontmatter
}

// Bad — organized by dependency, not domain
pub type NotesError {
  FileError(path: String, reason: simplifile.FileError)
  TomlError(path: String, reason: tom.ParseError)
}
```

### P2. Comment Liberally

**Severity:** P3 — Convention

Comments explaining both what code does and why it exists significantly improve maintainability. They are valuable even in well-written code.

```gleam
pub fn classify_file_content(content: String) -> FileOrigin {
  let likely_generated =
    // In newer versions of squirrel this is always at the beginning of the
    // file and it would be enough to check for this comment to establish if
    // a file is generated or not...
    string.contains(
      content,
      "> 🐿️ This module was generated automatically using",
    )
    // ...but in older versions that module comment is not present! So we
    // need to check if there's any function generated by squirrel.
    || string.contains(
      content,
      "> 🐿️ This function was generated automatically using",
    )

  case likely_generated {
    True -> LikelyGenerated
    False -> NotGenerated
  }
}
```

### P3. Make Invalid States Impossible

**Severity:** P1 — Architecture

Use custom types to encode business rules, preventing invalid data construction.

> See `type-design.md` for opaque types and parse-don't-validate patterns.

```gleam
// Bad — allows invalid combinations
pub type Visitor {
  Visitor(id: Option(Int), email: Option(String))
}

let invalid = Visitor(id: Some(123), email: None) // Half logged-in?

// Good — impossible to construct invalid state
pub type Visitor {
  LoggedInUser(id: Int, email: String)
  Guest
}
```

### P4. Replace Bools with Custom Types

**Severity:** P2 — Maintainability

Custom types provide clarity and prevent state confusion. When a boolean represents a domain concept, replace it with a custom type.

**Detection:** Grep for `Bool` in record field types. Flag when a record has 2+ Bool fields, or when field names suggest state (`is_active`, `is_loading`, `has_permission`, `is_student`).

```gleam
// Bad — ambiguous boolean
pub type SchoolPerson {
  SchoolPerson(name: String, is_student: Bool)
}

// Good — descriptive custom type
pub type SchoolPerson {
  SchoolPerson(name: String, role: Role)
}

pub type Role {
  Student
  Teacher
}
```

**In practice:** `is_active: Bool` → `status: AccountStatus` with `Active | Suspended | Deactivated`. `is_loading: Bool` + `data: Option(a)` → `RemoteData` union type (see `type-design.md`).

### P5. Sans-IO Pattern

**Severity:** P2 — Maintainability

Design HTTP client libraries without depending on specific HTTP implementations. Provide separate functions for request construction and response parsing.

This enables use across multiple targets (Erlang, JavaScript) and frameworks.

```gleam
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}

/// Construct a request for the create-user endpoint.
pub fn create_user_request(name: String) -> Request(String) {
  request.new()
  |> request.set_method(Post)
  |> request.set_host("example.com")
  |> request.set_body(json.to_string(json.object([#("name", name)])))
  |> request.prepend_header("accept", "application/json")
  |> request.prepend_header("content-type", "application/json")
}

/// Parse a response from the create-user endpoint.
pub fn create_user_response(
  response: Response(String),
) -> Result(Nil, ApiError) {
  case response.status {
    201 -> Ok(User(name: response.body))
    409 -> Error(UserNameAlreadyInUse)
    429 -> Error(RateLimitWasHit)
    code -> Error(GotUnexpectedResponse(code, response.body))
  }
}
```

**In practice:** See `backend/http-runner.md` for how our project implements this pattern.

### P6. Builder Pattern

**Severity:** P3 — Convention

Use builder functions for flexible record creation with optional fields. Builder functions return modified versions with selected fields changed.

```gleam
// Usage
button.new(text: "Continue")
|> button.colour("green")
|> button.large
|> button.to_html

// Implementation
pub type Button {
  Button(text: String, colour: String, classes: Set(String))
}

pub fn new(text text: String) -> Button {
  Button(text:, colour: "pink", classes: set.new())
}

pub fn colour(button: Button, value: String) -> Button {
  Button(..button, colour: value)
}

pub fn large(button: Button) -> Button {
  let classes = button.classes |> set.delete("small") |> set.insert("large")
  Button(..button, classes:)
}
```

---

## Anti-patterns (Avoid)

### A1. Abbreviations

**Severity:** P3 — Convention

Avoid shortened names. They hinder understanding and create ambiguity. Always use full names.

**Detection:** Grep for known abbreviations in let bindings, function names, and type names.

**Accepted exceptions:** `db`, `req`, `res`, `err`, `ctx`, `msg`, `id`, `fn` — widely understood in the Gleam/BEAM ecosystem.

```gleam
// Bad
let cap = 5
let off = 0
let cnt = proc_dat(ss)

// Good
let capacity = 5
let offset = 0
let continuation = process_data(session)
```

**Common violations to flag:** `cap`, `off`, `cnt`, `proc`, `dat`, `ss`, `btn`, `lbl`, `idx`, `num`, `tmp`, `str` (as variable), `val`, `conf`, `cfg`, `desc`, `impl`, `init`, `prev`, `curr`.

### A2. Fragmented Modules

**Severity:** P2 — Maintainability

Do not prematurely split code across multiple modules. Focus on coherent business domain APIs rather than artificially separating functionality. Large, well-designed modules are preferable to collections of fragmented ones.

**Detection:** Look for modules with <3 public functions that are siblings in the same domain directory. Also flag separate `types.gleam`, `constants.gleam`, `utilities.gleam` files within a domain.

```gleam
// Bad — requires importing 6 modules for one library
import my_library/client
import my_library/config
import my_library/decode
import my_library/error
import my_library/parser
import my_library/types

// Good — single coherent API
import my_library
```

### A3. Panicking in Libraries

**Severity:** P1 — Architecture

Libraries must never use `panic` or `let assert`. Return Results instead, giving users control over error handling.

**Exception:** OTP-related libraries may panic when supervision trees provide appropriate non-local error handling.

**Detection:** Grep for `let assert` and `panic` in non-test, non-OTP code.

### A4. Global Namespace Pollution

**Severity:** P3 — Convention

Place modules within a uniquely named package directory to avoid collisions.

```
// Good
src/
├── my_package.gleam
└── my_package/
    ├── distribution.gleam
    └── inventory.gleam

// Bad — pollutes global namespace
src/
├── distribution.gleam
├── inventory.gleam
└── my_package.gleam
```

### A5. Namespace Trespassing

**Severity:** P3 — Convention

Never place modules within another package's directory. For example, avoid placing code in `src/lustre/` unless you maintain that package.

### A6. Grouping by Design Pattern

**Severity:** P1 — Architecture

Organize modules around business domains, not programming patterns or abstractions.

**Detection:** Grep directory structure for `controllers/`, `services/`, `models/`, `repositories/`, `helpers/`, `utils/`, `types/`, `constants/`, `utilities/`, `functions/`, `functors/`, `monads/`.

```gleam
// Bad — grouped by programming pattern
import app/controllers/user_controller
import app/decorator/user_decorator
import app/model/user_model
import app/services/user_service
import app/views/user_view

// Bad — grouped by abstract category
import app/constants
import app/functions
import app/types
import app/utilities

// Good — grouped by business domain
import app/stock
import app/billing
```

**In practice:** Our project uses domain-based grouping: `core/auth/`, `tenant/catalog/`, `tenant/orders/`. Any new `controllers/`, `services/`, or `models/` directories should be flagged immediately.

### A7. Check-then-Assert

**Severity:** P1 — Architecture

Avoid checking conditions then asserting results. Use pattern matching and combinators instead.

**Detection:** Grep for `result.is_ok` or `result.is_error` near `let assert`. Also flag `bool.guard(when: result.is_error(...))` followed by `let assert Ok(...)`.

```gleam
// Bad — check then assert
case result.is_ok(data) {
  True -> {
    let assert Ok(value) = data
    process(value)
  }
  False -> data
}

// Bad — guard then assert
use <- bool.guard(when: result.is_error(data), return: data)
let assert Ok(value) = data
process(data)

// Good — pattern matching
case data {
  Ok(value) -> process(value)
  Error(e) -> Error(e)
}

// Good — combinators
data |> result.try(process)

// Good — use with result.try
use value <- result.try(data)
process(value)
```

### A8. Using Dynamic with FFI

**Severity:** P1 — Architecture

Never use `gleam/dynamic`'s `Dynamic` type for FFI. Create specific types representing expected values.

**Detection:** Grep for `Dynamic` in non-test code outside `gleam/dynamic` module usage.

```gleam
// Good — specific opaque type
pub type Buffer

pub fn byte_size(data: Buffer) -> Int

// Bad — generic Dynamic
import gleam/dynamic.{type Dynamic}

pub fn byte_size(data: Dynamic) -> Int
```

### A9. Catch-all Pattern Matching

**Severity:** P1 — Architecture

Avoid catch-all patterns. Explicitly match all variants to enable compiler assistance during refactoring. When you add a new variant, the compiler will tell you every place that needs updating — but only if you don't use `_`.

**Detection:** Grep for `_ ->` in case expressions on custom types. Cross-reference whether the matched value is a custom type with named variants. Strings, integers, and other open-ended types are exempt.

```gleam
// Bad — hides unhandled cases
case role {
  Student -> handle_student()
  _ -> handle_teacher()
}

// Good — explicit matching
case role {
  Student -> handle_student()
  Teacher -> handle_teacher()
}
```

**In practice:** This is especially dangerous in `update` functions (Lustre MVU) and error handlers where new variants get added frequently.

### A10. Category Theory Overuse

**Severity:** P3 — Convention

Avoid complex abstract category theory-based designs. Gleam lacks ergonomics and optimizations for these patterns. Solve specific problems with concrete solutions instead.

```gleam
// Bad — abstract category theory
pub fn sum(
  data: a,
  monoid: Monoid(a),
  catamorphism: Catamorphism(a, b),
) -> b {
  catamorphism.apply(data, monoid.empty, monoid.append)
}

// Good — concrete solution
pub fn total_cost(costs: List(Int)) -> Int {
  int.sum(costs)
}
```
