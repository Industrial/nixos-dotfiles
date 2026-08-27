# Type Design

## Parse, Don't Validate: Opaque Types for Validated Data

**Use `pub opaque type` for any data that requires validation.** This pattern ensures that once data is parsed, it's guaranteed to be valid throughout your codebase. The compiler enforces that only the module can create instances.

### Place Validated Types in Shared Module

**For full-stack Gleam applications, place opaque validation types in a `shared/` package** that compiles to both Erlang (server) and JavaScript (client) targets. This ensures:

1. **Single source of truth** - Same validation logic on server and client
2. **Type safety across boundaries** - Server returns `Email`, client receives `Email`
3. **Consistent error messages** - Same validation errors displayed to users
4. **No duplicate code** - Write once, use everywhere

**Correct monorepo structure:**

```
project/
├── server/
│   ├── gleam.toml          # target = "erlang"
│   └── src/                # Server code
│
├── client/
│   ├── gleam.toml          # target = "javascript"
│   └── src/                # Client code
│
└── shared/
    ├── gleam.toml          # NO target specified (works with both)
    └── src/shared/
        ├── email.gleam     # Opaque Email type
        ├── cpf.gleam       # Opaque CPF type (Brazil)
        ├── phone.gleam     # Opaque Phone type
        ├── password.gleam  # Opaque Password type
        ├── money.gleam     # Opaque Money type
        └── ...
```

**shared/gleam.toml (NO target field):**

```toml
name = "shared"
version = "1.0.0"
# NO target field - inherits from consumer

[dependencies]
gleam_stdlib = ">= 0.44.0"
gleam_json = ">= 2.0.0"
```

**Using shared types in server (server/gleam.toml):**

```toml
target = "erlang"

[dependencies]
shared = { path = "../shared" }
```

**Using shared types in client (client/gleam.toml):**

```toml
target = "javascript"

[dependencies]
shared = { path = "../shared" }
```

**Import and use the same types everywhere:**

```gleam
// Both server and client use the same import
import shared/email.{type Email}
import shared/cpf.{type Cpf}

// Server: validate incoming JSON
pub fn create_user_handler(json: Dynamic) -> Result(User, AppError) {
  use email <- result.try(decode.run(json, email.decoder()))
  // email is guaranteed valid Email type
  ...
}

// Client: validate form input before sending
pub fn handle_submit(form: FormData) -> Effect(Msg) {
  case email.parse(form.email_input) {
    Ok(email) -> api.create_user(email)  // Send validated Email
    Error(err) -> show_error(email.error_message(err))
  }
}
```

**What belongs in shared vs server-only:**

| In `shared/`                   | In `server/src/`     |
| ------------------------------ | -------------------- |
| Email, Phone, CPF validation   | Database operations  |
| Money, Quantity types          | HTTP handlers        |
| Product, Order, Customer types | Authentication logic |
| JSON encoders/decoders         | File system access   |
| Validation error types         | External API clients |
| Pure business logic            | Server configuration |

**Key rule:** If it needs IO (database, HTTP, files), keep it server-only. If it's pure validation or data transformation, put it in shared.

### When to Use Opaque Types

Use opaque types for:

- **Identifiers**: Email, CPF, CNPJ, UUID, SKU, ISBN
- **Credentials**: Password, API keys, tokens
- **Formatted data**: Phone numbers, postal codes, URLs
- **Constrained values**: Positive integers, non-empty strings, percentages (0-100)
- **Domain-specific**: Currency amounts, quantities, coordinates

### The Pattern

Every opaque validated type should have these components:

```gleam
/// 1. Opaque type - hides the internal representation
pub opaque type Email {
  Email(value: String)
}

/// 2. Error type - specific validation failures
pub type EmailError {
  EmptyEmail
  TooLong
  MissingAtSign
  InvalidDomain
}

/// 3. Parse function - the ONLY way to create an instance
pub fn parse(str: String) -> Result(Email, EmailError) {
  let str = string.trim(str)

  use <- bool.guard(string.is_empty(str), Error(EmptyEmail))
  use <- bool.guard(string.length(str) > 254, Error(TooLong))

  case string.split(str, "@") {
    [local, domain] -> {
      use <- bool.guard(string.is_empty(local), Error(MissingAtSign))
      use <- bool.guard(!has_valid_domain(domain), Error(InvalidDomain))
      Ok(Email(str))
    }
    _ -> Error(MissingAtSign)
  }
}

/// 4. Accessor - safe way to get the validated value
pub fn to_string(email: Email) -> String {
  email.value
}

/// 5. JSON decoder - validates during deserialization
pub fn decoder() -> decode.Decoder(Email) {
  use str <- decode.then(decode.string)
  case parse(str) {
    Ok(email) -> decode.success(email)
    Error(_) -> decode.failure(Email(""), "Email")
  }
}

/// 6. JSON encoder
pub fn to_json(email: Email) -> Json {
  json.string(email.value)
}

/// 7. Error messages for users
pub fn error_message(err: EmailError) -> String {
  case err {
    EmptyEmail -> "Email is required"
    TooLong -> "Email is too long (max 254 characters)"
    MissingAtSign -> "Invalid email format"
    InvalidDomain -> "Invalid email domain"
  }
}
```

### Complete Example: CPF (Brazilian Tax ID)

```gleam
/// Brazilian CPF with check digit validation
pub opaque type Cpf {
  Cpf(value: String)
}

pub type CpfError {
  InvalidLength
  InvalidFormat
  InvalidCheckDigit
  AllSameDigit
}

pub fn parse(str: String) -> Result(Cpf, CpfError) {
  let digits = extract_digits(str)

  use <- bool.guard(string.length(digits) != 11, Error(InvalidLength))
  use <- bool.guard(all_same_digit(digits), Error(AllSameDigit))
  use <- bool.guard(!valid_check_digits(digits), Error(InvalidCheckDigit))

  Ok(Cpf(digits))
}

pub fn to_string(cpf: Cpf) -> String {
  cpf.value
}

/// Format as XXX.XXX.XXX-XX
pub fn format(cpf: Cpf) -> String {
  let v = cpf.value
  string.slice(v, 0, 3) <> "." <>
  string.slice(v, 3, 3) <> "." <>
  string.slice(v, 6, 3) <> "-" <>
  string.slice(v, 9, 2)
}

pub fn decoder() -> decode.Decoder(Cpf) {
  use str <- decode.then(decode.string)
  case parse(str) {
    Ok(cpf) -> decode.success(cpf)
    Error(_) -> decode.failure(Cpf(""), "Cpf")
  }
}

/// Encode as formatted string for display
pub fn to_json(cpf: Cpf) -> Json {
  json.string(format(cpf))
}

/// Encode as raw digits for storage
pub fn to_json_raw(cpf: Cpf) -> Json {
  json.string(cpf.value)
}

pub fn error_message(err: CpfError) -> String {
  case err {
    InvalidLength -> "CPF must have 11 digits"
    InvalidFormat -> "Invalid CPF format"
    InvalidCheckDigit -> "Invalid CPF check digit"
    AllSameDigit -> "Invalid CPF (all same digit)"
  }
}
```

### Using Validated Types in Your Domain

```gleam
/// BAD - Using raw strings allows invalid data
pub type User {
  User(
    email: String,      // Could be "not-an-email"
    cpf: String,        // Could be "12345"
    phone: String,      // Could be anything
  )
}

fn create_user(email: String, cpf: String) -> User {
  // No validation! Invalid data can propagate
  User(email:, cpf:, phone: "")
}

/// GOOD - Opaque types guarantee validity
pub type User {
  User(
    email: Email,       // Must be valid email
    cpf: Cpf,           // Must be valid CPF
    phone: Phone,       // Must be valid phone
  )
}

fn create_user(
  email_str: String,
  cpf_str: String,
) -> Result(User, ValidationError) {
  use email <- result.try(email.parse(email_str) |> result.map_error(EmailErr))
  use cpf <- result.try(cpf.parse(cpf_str) |> result.map_error(CpfErr))
  Ok(User(email:, cpf:, phone: phone.empty()))
}
```

### Bridging Opaque Types to UI State (Frontend)

Opaque types like `Email` represent a *valid* state. However, frontend forms need to represent *invalid* or *half-typed* states while the user is typing. 

**Do NOT use detached error dictionaries** (`field_errors: Dict(String, String)`) alongside raw string fields.

**DO use a FieldState wrapper** that co-locates the raw input, the parsed opaque type, and the domain-specific error.

```gleam
import shared/validation/email.{type Email, type EmailError}

// Frontend Model
pub type CustomerForm {
  CustomerForm(
    // Holds the raw string, the parsed opaque `Email` (if valid), or the `EmailError`
    email: FieldState(Email, EmailError), 
  )
}
```

### Async Page State: RemoteData

A page that loads data over the network has four states, not a `Bool` + `Option`. Model them as one union so the loading flag and the payload can never disagree.

```gleam
// BAD — detached: is_loading can be True while data is Some, or both empty
pub type ProductsPage {
  ProductsPage(
    is_loading: Bool,
    data: Option(List(Product)),
    error: Option(String),
  )
}

// GOOD — the payload lives *inside* the loaded variant
pub type RemoteData(value, error) {
  RemoteIdle
  RemoteLoading
  RemoteLoaded(value)
  RemoteFailed(error)
}

pub type Model {
  Model(products: RemoteData(List(Product), ErrorCode))
}
```

Guard behaviorally with predicates (`remote.is_loading`, `remote.is_failed`) rather than reaching into the variant in the view. The failure carries a typed `ErrorCode` (see `error-handling.md`), never a stringly message. A form's *save* lifecycle uses the same shape — see `Submit` in the lustre skill's `advanced-mvu-forms.md`.

### Unified Validation Module

For domains with multiple validated types, create a unified validation module:

```gleam
/// validation/validation.gleam
import validation/email.{type Email}
import locale/br/cpf.{type Cpf, type CpfError}
import locale/br/cnpj.{type Cnpj, type CnpjError}

pub type ValidationError {
  EmailValidationError(String)
  CpfValidationError(CpfError)
  CnpjValidationError(CnpjError)
  TaxIdRequired
}

pub fn validate_email(str: String) -> Result(Email, ValidationError) {
  email.parse(str)
  |> result.map_error(EmailValidationError)
}

pub fn validate_cpf(str: String) -> Result(Cpf, ValidationError) {
  cpf.parse(str)
  |> result.map_error(CpfValidationError)
}

pub fn validate_optional_email(
  opt: Option(String),
) -> Result(Option(Email), ValidationError) {
  case opt {
    None -> Ok(None)
    Some(str) -> email.parse(str) |> result.map(Some) |> result.map_error(EmailValidationError)
  }
}

pub fn error_message(err: ValidationError) -> String {
  case err {
    EmailValidationError(msg) -> msg
    CpfValidationError(e) -> cpf.error_message(e)
    CnpjValidationError(e) -> cnpj.error_message(e)
    TaxIdRequired -> "Tax ID is required"
  }
}
```

### Key Benefits

1. **Compile-time safety**: Cannot accidentally pass unvalidated data
2. **Single validation point**: Parse once at the boundary, trust everywhere else
3. **Self-documenting**: Function signatures show what's validated
4. **Testable**: Validation logic is isolated and easy to test
5. **Refactorable**: Internal representation can change without affecting users

### Anti-Patterns to Avoid

```gleam
/// BAD - Validation scattered throughout codebase
fn send_email(email: String) {
  case is_valid_email(email) {  // Repeated validation!
    True -> do_send(email)
    False -> Error("Invalid email")
  }
}

/// BAD - Boolean validation functions
fn is_valid_email(str: String) -> Bool  // Loses error information

/// BAD - Exposing the constructor
pub type Email {            // Not opaque! Anyone can create Email("garbage")
  Email(value: String)
}

/// GOOD - Opaque type with parse function
pub opaque type Email { Email(value: String) }
pub fn parse(str: String) -> Result(Email, EmailError)
```

## Modules Name

Gleam modules should be singular.

```gleam
/// Bad naming
import auth/users
import auth/handlers

/// Good naming
import auth/user
import auth/handler
```

## Module Ordering: Top to Bottom

Organize modules so the reader encounters the most important code first, with details flowing downward. Think of it like a newspaper article — headline first, supporting details below.

### Order within a module

1. **Imports** — at the very top
2. **Public functions** — ordered by importance (the module's main purpose comes first)
3. **Private helper functions** — directly below the public function that calls them
4. **Types and type aliases** — at the bottom of the module

### Why types go at the bottom

Types are definitions, not behavior. A reader opening a module wants to understand *what it does*, not *what shapes of data exist*. Place types at the bottom so the logic reads like a narrative from entry point to implementation detail.

### Example

```gleam
// --- Imports ---
import gleam/list
import gleam/result

// --- Main public function (the module's reason to exist) ---
pub fn process_order(order: Order) -> Result(Receipt, OrderError) {
  use validated <- result.try(validate(order))
  use total <- result.try(calculate_total(validated))
  Ok(Receipt(order_id: order.id, total:))
}

// --- Supporting public functions ---
pub fn cancel_order(order: Order) -> Result(Nil, OrderError) {
  // ...
}

// --- Private helpers (below the public functions that use them) ---
fn validate(order: Order) -> Result(Order, OrderError) {
  // ...
}

fn calculate_total(order: Order) -> Result(Int, OrderError) {
  // ...
}

// --- Types at the bottom ---
pub type Order {
  Order(id: String, items: List(Item), status: Status)
}

pub type Receipt {
  Receipt(order_id: String, total: Int)
}

pub type OrderError {
  EmptyOrder
  InvalidItem(String)
  CalculationError
}

pub type Item {
  Item(name: String, price: Int, quantity: Int)
}

pub type Status {
  Pending
  Confirmed
  Cancelled
}
```

### Anti-pattern

```gleam
/// BAD - Types at top push the actual logic down, forcing the reader to scroll
pub type Order { ... }
pub type Receipt { ... }
pub type OrderError { ... }
pub type Item { ... }
pub type Status { ... }

pub fn process_order(order: Order) -> Result(Receipt, OrderError) {
  // Reader has to scroll past type definitions to find what this module does
}
```
