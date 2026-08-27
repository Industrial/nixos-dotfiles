# Input Validation with valid

Use `valid` for composable, error-accumulating validation that transforms unvalidated
input into typed, validated output.

## Installation

```sh
gleam add valid@5
```

## Core Concept

`valid` follows the **"Parse, Don't Validate"** principle. Instead of checking conditions
and returning booleans, validators **transform** input types into validated output types.
An `InputUser` with raw strings becomes a `ValidUser` with guaranteed-valid fields.

**Error accumulation:** When using `check`, ALL validators run even if earlier ones fail.
Every validator provides a default output on failure so subsequent validators can still
execute. All errors are collected into a single list.

## Types

```gleam
/// A validator is a function from input to (output, errors).
pub type Validator(input, output, error) =
  fn(input) -> ValidatorResult(output, error)

/// Always a tuple: output value + error list.
/// On success the error list is empty. On failure the output is a default.
pub type ValidatorResult(output, error) =
  #(output, List(error))
```

## Quick Start

```gleam
import valid

pub type InputUser {
  InputUser(age: Int, name: String, email: String)
}

pub type ValidUser {
  ValidUser(age: Int, name: String, email: String)
}

fn user_validator(input: InputUser) {
  use age <- valid.check(input.age, valid.int_min(13, "Must be 13+"))
  use name <- valid.check(input.name, valid.string_is_not_empty("Name required"))
  use email <- valid.check(input.email, valid.string_is_email("Invalid email"))
  valid.ok(ValidUser(age:, name:, email:))
}

pub fn validate_user(input: InputUser) -> Result(ValidUser, List(String)) {
  valid.validate(input, user_validator)
}

// Ok(ValidUser(14, "Sam", "sam@example.com"))
validate_user(InputUser(14, "Sam", "sam@example.com"))

// Error(["Must be 13+", "Name required", "Invalid email"]) — ALL errors collected
validate_user(InputUser(10, "", "bad"))
```

## Core Functions

### validate — Entry Point

```gleam
pub fn validate(
  input input: in,
  validator validator: fn(in) -> #(a, List(b)),
) -> Result(a, List(b))
```

Runs a validator and converts the result tuple into a standard `Result`:
- Empty error list -> `Ok(output)`
- Non-empty error list -> `Error(errors)`

### check — Accumulate Errors

```gleam
pub fn check(
  input input: in,
  validator validator: fn(in) -> #(out, List(err)),
  next next: fn(out) -> #(a, List(err)),
) -> #(a, List(err))
```

The core combinator. Designed for `use` syntax — validates `input`, passes the result
(or default on failure) to `next`. Errors from all checks accumulate.

```gleam
fn validator(input: Input) {
  use name <- valid.check(input.name, valid.string_is_not_empty("Name"))
  use age <- valid.check(input.age, valid.int_min(0, "Age"))
  valid.ok(Output(name:, age:))
}
```

### ok — Success

```gleam
pub fn ok(output: a) -> #(a, List(b))
```

Creates a successful result. Used as the final step in a `check` chain.

### fail — Failure

```gleam
pub fn fail(default: a, error: b) -> #(a, List(b))
```

Creates a failed result with one error and a default value. Useful for cross-field
validation after individual checks.

## Built-in Validators

### String Validators

```gleam
// Non-empty
valid.string_is_not_empty(error: "Required")
// Validator(String, String, err)

// Length bounds
valid.string_min_length(min: 3, error: "Too short")
valid.string_max_length(max: 100, error: "Too long")
// Validator(String, String, err)

// Email (simple _@_ check)
valid.string_is_email(error: "Invalid email")
// Validator(String, String, err)

// Regex match
valid.string_matches_regex(re: my_regex, error: "No match")
// Validator(String, String, err)

// Parse string to Int (changes output type!)
valid.string_is_int(error: "Not a number")
// Validator(String, Int, err)

// Parse string to Float (accepts "1" as 1.0)
valid.string_is_float(error: "Not a number")
// Validator(String, Float, err)

// Parse string to Float (rejects "1", requires "1.0")
valid.string_is_float_strict(error: "Not a decimal")
// Validator(String, Float, err)

// Parse string to Bool
valid.string_is_bool(error: "Not a boolean")
// Validator(String, Bool, err)
```

### Integer Validators

```gleam
valid.int_min(min: 0, error: "Must be positive")
valid.int_max(max: 150, error: "Too large")
// Validator(Int, Int, err)
```

## Combinators

### all — Multiple Rules on Same Value

```gleam
pub fn all(validators: List(Validator(in, in, e))) -> Validator(in, in, e)
```

Runs all validators on the same input, collecting all errors. Input and output types
must be the same.

```gleam
let password_rules = valid.all([
  valid.string_min_length(8, "Min 8 chars"),
  valid.string_matches_regex(upper_re, "Need uppercase"),
  valid.string_matches_regex(digit_re, "Need digit"),
])

fn validator(input: Input) {
  use password <- valid.check(input.password, password_rules)
  valid.ok(password)
}
```

### then — Sequential Composition (Short-Circuit)

```gleam
pub fn then(
  first_validator first_validator: fn(a) -> #(b, List(c)),
  second_validator second_validator: fn(b) -> #(b, List(c)),
) -> fn(a) -> #(b, List(c))
```

Chains two validators sequentially. The second only runs if the first succeeds.
Use when the second validator depends on the first's output.

```gleam
// Unwrap Option, then check length
let validator =
  valid.is_some("", valid.ok, "Required")
  |> valid.then(valid.string_min_length(2, "Too short"))

// None -> Error(["Required"])           — short-circuits
// Some("") -> Error(["Too short"])      — first passes, second fails
// Some("Sam") -> Ok("Sam")             — both pass
```

### is_some — Unwrap Option

```gleam
pub fn is_some(
  default default: out,
  validator validator: Validator(in, out, err),
  error error: err,
) -> Validator(Option(in), out, err)
```

Validates that an `Option` is `Some`, unwraps it, and runs the inner validator.
If `None`, returns the default with the error.

```gleam
// Just unwrap (no inner validation)
valid.is_some("", valid.ok, "Required")

// Unwrap + parse
valid.is_some(0, valid.string_is_int("Not a number"), "Required")
// Some("42") -> #(42, [])
// None -> #(0, ["Required"])
```

### optional — Skip if None

```gleam
pub fn optional(
  validator validator: fn(input) -> #(a, List(b)),
) -> fn(Option(input)) -> #(Option(a), List(b))
```

Makes a validator work on `Option` types. `None` passes through with no errors.
`Some(value)` runs the validator and wraps output back in `Some`.

```gleam
fn validator(input: Input) {
  use nickname <- valid.check(
    input.nickname,
    valid.optional(valid.string_min_length(2, "Too short")),
  )
  valid.ok(Output(nickname:))
}
// None -> Ok(Output(nickname: None))
// Some("Jo") -> Ok(Output(nickname: Some("Jo")))
// Some("J") -> Error(["Too short"])
```

### list_all — Validate Every Element

```gleam
pub fn list_all(
  validator validator: fn(in) -> #(out, List(err)),
) -> fn(List(in)) -> #(List(out), List(err))
```

Applies a validator to every element in a list. Returns validated outputs and
collected errors.

```gleam
fn validator(input: Input) {
  use tags <- valid.check(
    input.tags,
    valid.list_all(valid.string_is_not_empty("Tag required")),
  )
  valid.ok(Output(tags:))
}
```

## Patterns

### Custom Validators

Any function matching `fn(input) -> #(output, List(error))` is a validator. You must
provide a default output on failure for error accumulation to work.

```gleam
fn is_positive(input: Int) -> #(Int, List(String)) {
  case input > 0 {
    True -> #(input, [])
    False -> #(0, ["Must be positive"])
  }
}

fn is_unique_email(
  db: pog.Connection,
) -> valid.Validator(String, String, String) {
  fn(email: String) -> #(String, List(String)) {
    case sql.check_email_exists(db, email) {
      Ok(pog.Returned(0, _)) -> #(email, [])
      _ -> #("", ["Email already taken"])
    }
  }
}
```

### Structured Errors (Field-Level)

Use custom error types instead of plain strings for field-level error reporting:

```gleam
pub type Field {
  FieldName
  FieldEmail
  FieldAge
}

pub type ValidationError {
  ValidationError(field: Field, message: String)
}

fn user_validator(input: InputUser) {
  use name <- valid.check(
    input.name,
    valid.string_is_not_empty(ValidationError(FieldName, "Required")),
  )
  use email <- valid.check(
    input.email,
    valid.string_is_email(ValidationError(FieldEmail, "Invalid")),
  )
  use age <- valid.check(
    input.age,
    valid.int_min(13, ValidationError(FieldAge, "Must be 13+")),
  )
  valid.ok(ValidUser(name:, email:, age:))
}
// Error([ValidationError(FieldName, "Required"), ValidationError(FieldAge, "Must be 13+")])
```

### Cross-Field Validation

Use `fail` after individual checks for rules that span multiple fields:

```gleam
fn password_validator(input: PasswordInput) {
  use password <- valid.check(
    input.password,
    valid.string_min_length(8, "Min 8 chars"),
  )
  use confirmation <- valid.check(
    input.confirmation,
    valid.string_is_not_empty("Confirm password"),
  )
  case password == confirmation {
    True -> valid.ok(password)
    False -> valid.fail("", "Passwords don't match")
  }
}
```

### Input Transformation

Transform input before validating by passing transformed value with `valid.ok`:

```gleam
fn validator(input: String) {
  use trimmed <- valid.check(string.trim(input), valid.ok)
  use _ <- valid.check(trimmed, valid.string_is_not_empty("Required"))
  valid.ok(trimmed)
}
// "  Sam  " -> Ok("Sam")
```

### Parsing Form Input (String to Typed)

Use parsing validators (`string_is_int`, `string_is_float`) to transform raw form
strings into typed values:

```gleam
pub type FormInput {
  FormInput(name: String, age: String, score: String)
}

pub type ValidForm {
  ValidForm(name: String, age: Int, score: Float)
}

fn form_validator(input: FormInput) {
  use name <- valid.check(input.name, valid.string_is_not_empty("Name required"))
  use age <- valid.check(input.age, valid.string_is_int("Age must be a number"))
  use score <- valid.check(input.score, valid.string_is_float("Score must be a number"))
  valid.ok(ValidForm(name:, age:, score:))
}
```

## Complete Validation Module Example

```gleam
//// validation/user.gleam - User validation module

import gleam/option.{type Option}
import gleam/regexp
import valid

pub type UserInput {
  UserInput(
    name: String,
    email: String,
    age: String,
    bio: Option(String),
    tags: List(String),
  )
}

pub type ValidUser {
  ValidUser(
    name: String,
    email: String,
    age: Int,
    bio: Option(String),
    tags: List(String),
  )
}

pub type Field {
  Name
  Email
  Age
  Bio
  Tags
}

pub type ValidationError {
  ValidationError(field: Field, message: String)
}

pub fn validate_user(
  input: UserInput,
) -> Result(ValidUser, List(ValidationError)) {
  valid.validate(input, user_validator)
}

fn user_validator(input: UserInput) {
  use name <- valid.check(
    input.name,
    valid.all([
      valid.string_is_not_empty(ValidationError(Name, "Required")),
      valid.string_min_length(2, ValidationError(Name, "Min 2 characters")),
      valid.string_max_length(100, ValidationError(Name, "Max 100 characters")),
    ]),
  )
  use email <- valid.check(
    input.email,
    valid.string_is_email(ValidationError(Email, "Invalid email")),
  )
  use age <- valid.check(
    input.age,
    valid.string_is_int(ValidationError(Age, "Must be a number"))
    |> valid.then(valid.int_min(13, ValidationError(Age, "Must be 13+")))
    |> valid.then(valid.int_max(150, ValidationError(Age, "Invalid age"))),
  )
  use bio <- valid.check(
    input.bio,
    valid.optional(
      valid.string_max_length(500, ValidationError(Bio, "Max 500 characters")),
    ),
  )
  use tags <- valid.check(
    input.tags,
    valid.list_all(
      valid.string_is_not_empty(ValidationError(Tags, "Tag cannot be empty")),
    ),
  )
  valid.ok(ValidUser(name:, email:, age:, bio:, tags:))
}
```

## Best Practices

1. **Use typed errors, not strings** — custom error types with field identifiers make
   it easy to map errors to UI fields
2. **Separate input and output types** — `InputUser` vs `ValidUser` makes the
   parse-don't-validate pattern explicit at the type level
3. **Use `all` for multiple rules on one field** — collects all violations at once
   instead of stopping at the first
4. **Use `then` for dependent validations** — parse first, then validate the parsed
   value (e.g., `string_is_int` then `int_min`)
5. **Use `optional` for nullable fields** — skips validation when `None`
6. **Keep validators as plain functions** — they compose naturally and are easy to test
7. **`fail` for cross-field rules** — password confirmation, date range checks, etc.
   go at the end of the `check` chain
