# Auth: Password Hashing & Timestamps

## Antigone Password Hashing

Use the `antigone` library for Argon2 password hashing. **Critical: Never compare hashes directly.**

```gleam
import antigone

// Hash password for storage
let hash = antigone.hash(password)

// Verify password - ALWAYS use verify()
case antigone.verify(user_input, stored_hash) {
  Ok(True) -> Ok(user)           // Password matches
  Ok(False) -> Error(Unauthorized)  // Wrong password
  Error(_) -> Error(InternalError)  // Hash corruption or invalid format
}
```

**CRITICAL - Why direct comparison NEVER works:**

Argon2 hashes include a **random salt** embedded in the hash string. Each call to `antigone.hash()` generates a different salt, producing a different hash even for the same password.

```gleam
/// WRONG - Will NEVER match! Comparing two different salts
case stored_hash == antigone.hash(input) {
  True -> Ok(user)   // This condition is NEVER true!
  False -> Error(Unauthorized)
}

// Hash of "password123" (first call):
// $argon2id$v=19$m=19456,t=2,p=1$RANDOM_SALT_A$derived_key_A

// Hash of "password123" (second call):
// $argon2id$v=19$m=19456,t=2,p=1$RANDOM_SALT_B$derived_key_B
// Different salt = different hash, even for identical password!

/// CORRECT - verify() extracts salt from stored_hash and uses it
case antigone.verify(input, stored_hash) {
  Ok(True) -> Ok(user)  // Salt extracted, password re-hashed with same salt, matches!
  ...
}
```

**Best practices:**

- Always use `antigone.verify()` for password checking
- Store the full hash string (includes algorithm, salt, and derived key)
- Handle `Error(_)` from verify - indicates corrupted or invalid hash format
- Never log passwords or hashes

## gleam/time Module Reference

The `gleam/time` module provides cross-platform timestamp handling. Use `gleam/time/timestamp` for time operations and `gleam/time/calendar` for conversions.

```gleam
import gleam/time/timestamp
import gleam/time/calendar

// Get current time
let now = timestamp.system_time()  // NOT timestamp.now() - doesn't exist!

// Create from Unix seconds (takes Int, NOT Float)
let ts = timestamp.from_unix_seconds(1706745600)

// Convert to Unix seconds (returns Float, NOT Int)
let unix_float = timestamp.to_unix_seconds(ts)  // 1706745600.0

// To get Int, use truncate
let unix_int = float.truncate(timestamp.to_unix_seconds(ts))

// Get time difference
let dur = timestamp.difference(start_time, end_time)
let ms = float.truncate(duration.to_seconds(dur) *. 1000.0)

// Convert to calendar components
let #(date, time) = timestamp.to_calendar(ts, calendar.utc_offset)
// date: calendar.Date { year: Int, month: calendar.Month, day: Int }
// time: calendar.TimeOfDay { hours: Int, minutes: Int, seconds: Int, nanoseconds: Int }
```

**Common mistakes:**

- `timestamp.now()` doesn't exist - use `timestamp.system_time()`
- `from_unix_seconds` takes `Int`, not `Float`
- `timestamp.utc` doesn't exist - use `calendar.utc_offset`
- `to_unix_seconds` returns `Float`, use `float.truncate()` for `Int`
