# Standard Library & Data Processing

## Useful stdlib Functions

These are easy to overlook but very handy:

```gleam
// string.to_option - converts empty string to None
string.to_option("")       // None
string.to_option("hello")  // Some("hello")

// string.inspect - converts ANY value to a string representation
string.inspect([1, 2, 3])  // "[1, 2, 3]"
string.inspect(Ok(42))     // "Ok(42)"

// function.identity - pass-through, useful as a no-op transformer
list.filter_map(items, function.identity)  // keeps only Ok values

// result.values - extract Ok values from a list of Results
result.values([Ok(1), Error("x"), Ok(3)])  // [1, 3]

// result.replace - replace the Ok value
result.replace(Ok(1), "done")  // Ok("done")
result.replace(Error(e), "done")  // Error(e)

// result.try_recover - try to recover from an error
result.try_recover(Error("not found"), fn(_) { Ok(default_value) })

// result.lazy_unwrap - unwrap with lazy default
result.lazy_unwrap(maybe_result, fn() { compute_default() })

// option.or / option.lazy_or - first Some wins
option.or(None, Some(1))  // Some(1)
option.or(Some(1), Some(2))  // Some(1)

// option.then - like result.try but for Option (map + flatten)
option.then(Some(1), fn(x) { Some(x + 1) })  // Some(2)
option.then(None, fn(x) { Some(x + 1) })     // None

// list.fold_until - fold with early termination
list.fold_until([1, 2, 3, 4], 0, fn(acc, i) {
  case i < 3 {
    True -> list.Continue(acc + i)
    False -> list.Stop(acc)
  }
})
// -> 3
```

## Use Standard Library for Type Conversions

**NEVER write manual type conversion functions.** Gleam's standard library provides efficient, tested functions for all common conversions.

### Int conversions (`gleam/int`)

```gleam
import gleam/int

// Int to String
int.to_string(42)        // "42"
int.to_string(-5)        // "-5"

// String to Int (returns Result)
int.parse("42")          // Ok(42)
int.parse("-5")          // Ok(-5)
int.parse("abc")         // Error(Nil)
int.parse("12.5")        // Error(Nil)

// Base conversions
int.to_base_string(255, 16)  // "ff"
int.base_parse("ff", 16)     // Ok(255)

// Other useful functions
int.absolute_value(-42)  // 42
int.min(3, 7)            // 3
int.max(3, 7)            // 7
int.clamp(15, 0, 10)     // 10
int.is_even(4)           // True
int.is_odd(4)            // False
```

### Float conversions (`gleam/float`)

```gleam
import gleam/float

// Float to String
float.to_string(3.14)    // "3.14"

// String to Float (returns Result)
float.parse("3.14")      // Ok(3.14)
float.parse("abc")       // Error(Nil)

// Int to Float (always succeeds)
int.to_float(42)         // 42.0

// Float to Int (truncates toward zero)
float.truncate(3.7)      // 3
float.truncate(-3.7)     // -3
float.round(3.5)         // 4
float.floor(3.7)         // 3.0
float.ceiling(3.2)       // 4.0

// Other useful functions
float.absolute_value(-3.14)  // 3.14
float.min(1.5, 2.5)          // 1.5
float.max(1.5, 2.5)          // 2.5
float.clamp(15.0, 0.0, 10.0) // 10.0
float.power(2.0, 3.0)        // Ok(8.0)
float.square_root(16.0)      // Ok(4.0)
```

### String utilities (`gleam/string`)

```gleam
import gleam/string

// Common operations
string.length("hello")           // 5
string.reverse("hello")          // "olleh"
string.uppercase("hello")        // "HELLO"
string.lowercase("HELLO")        // "hello"
string.capitalise("hello")       // "Hello"

// Trimming
string.trim("  hello  ")         // "hello"
string.trim_start("  hello")     // "hello"
string.trim_end("hello  ")       // "hello"

// Splitting and joining
string.split("a,b,c", ",")       // ["a", "b", "c"]
string.join(["a", "b", "c"], "-") // "a-b-c"

// Checking contents
string.contains("hello", "ell")  // True
string.starts_with("hello", "he") // True
string.ends_with("hello", "lo")  // True
string.is_empty("")              // True

// Slicing
string.slice("hello", 1, 3)      // "ell"
string.drop_start("hello", 2)    // "llo"
string.drop_end("hello", 2)      // "hel"

// Padding (useful for formatting)
string.pad_start("42", 5, "0")   // "00042"
string.pad_end("hi", 5, ".")     // "hi..."

// Replacement
string.replace("hello", "l", "L") // "heLLo"
```

### Bad vs Good Examples

```gleam
/// BAD - Manual int to string conversion
fn int_to_string(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    // ... tedious and error-prone
    _ -> do_int_to_string(n, "")
  }
}

/// GOOD - Use standard library
import gleam/int
let s = int.to_string(n)
```

```gleam
/// BAD - Manual string parsing
fn parse_quantity(s: String) -> Option(Int) {
  do_parse_int(string.to_graphemes(s), 0, False)
}

/// GOOD - Use standard library with Result handling
import gleam/int
import gleam/option.{type Option, None, Some}

fn parse_quantity(s: String) -> Option(Int) {
  case int.parse(string.trim(s)) {
    Ok(n) -> Some(n)
    Error(_) -> None
  }
}
```

```gleam
/// BAD - Manual float formatting
fn format_price(cents: Int) -> String {
  // Complex manual division and string building...
}

/// GOOD - Use standard library
import gleam/int
import gleam/float

fn format_price(cents: Int) -> String {
  let dollars = int.to_float(cents) /. 100.0
  float.to_string(dollars)
}
```

## Data Processing Libraries

### gsv - CSV Parsing and Generation

Use `gsv` for parsing and generating CSV/TSV files. It's RFC 4180 compliant with convenience additions.

**When to use:**

- Parsing CSV/TSV files or strings
- Generating CSV exports
- Working with tabular data from external sources

```gleam
import gsv

// Parse CSV string to list of lists
let rows = gsv.to_lists("name,age\nAlice,30\nBob,25", separator: ",")
// Ok([["name", "age"], ["Alice", "30"], ["Bob", "25"]])

// Parse CSV with headers to list of dicts (recommended for structured data)
let records = gsv.to_dicts("name,age\nAlice,30", separator: ",")
// Ok([dict.from_list([#("name", "Alice"), #("age", "30")])])

// Generate CSV from lists
let csv = gsv.from_lists([["a", "b"], ["c", "d"]], separator: ",", line_ending: gsv.Unix)
// "a,b\nc,d\n"

// Generate CSV from dicts (auto-generates headers)
let csv = gsv.from_dicts(records, separator: ",", line_ending: gsv.Unix)
```

**Best practices:**

- Use `to_dicts` when rows have headers - provides type-safe field access
- Use `to_lists` for headerless data or when you need positional access
- Handle `ParseError` results: `UnescapedQuote` and `UnclosedEscapedField`
- Specify `line_ending: gsv.Unix` for consistency (or `gsv.Windows` for CRLF)

### splitter - Efficient String Splitting

Use `splitter` when you need to split strings multiple times with the same pattern(s). Creates a reusable splitter object for better performance.

**When to use:**

- Splitting the same pattern across many strings
- Parsing protocols or formats with multiple delimiters (e.g., `\n` and `\r\n`)
- Performance-critical string parsing loops

```gleam
import splitter

// Create a reusable splitter (do this ONCE, reuse many times)
let line_ends = splitter.new(["\r\n", "\n"])  // Order matters: longer patterns first

// Split returns #(before, matched, after)
splitter.split(line_ends, "line1\nline2\nline3")
// #("line1", "\n", "line2\nline3")

// Split before returns #(before, matched+after)
splitter.split_before(line_ends, "line1\nline2")
// #("line1", "\nline2")

// Split after returns #(before+matched, after)
splitter.split_after(line_ends, "line1\nline2")
// #("line1\n", "line2")

// Check if pattern exists without splitting
splitter.would_split(line_ends, "no newlines here")
// False
```

**Best practices:**

- Create splitter ONCE and reuse - there's overhead in `splitter.new()`
- Order patterns from longest to shortest (e.g., `["\r\n", "\n"]` not `["\n", "\r\n"]`)
- Use `would_split` for existence checks without allocating result tuples
- Prefer over `string.split` when splitting repeatedly with same pattern

### glearray - O(1) Indexed Arrays

Use `glearray` when you need fast random access by index. Unlike lists (O(n) access), arrays provide O(1) indexed reads.

**When to use:**

- Frequent index-based lookups (e.g., CSV headers by column position)
- Building lookup tables that won't change
- Algorithms requiring random access patterns

```gleam
import glearray

// Convert from list (do this once)
let headers = glearray.from_list(["id", "name", "email"])

// O(1) index access
glearray.get(headers, 0)  // Ok("id")
glearray.get(headers, 99) // Error(Nil)

// With default for missing indices
glearray.get_or_default(headers, 99, "unknown")  // "unknown"

// O(1) length
glearray.length(headers)  // 3

// Convert back to list when needed
glearray.to_list(headers)  // ["id", "name", "email"]
```

**When NOT to use:**

- Building incrementally (each `copy_push` copies entire array - O(n))
- Frequent modifications (use lists instead)
- Sequential iteration only (lists are fine)

```gleam
/// BAD - O(n^2) because each push copies the array
let array = glearray.new()
let array = glearray.copy_push(array, 1)  // Copies entire array
let array = glearray.copy_push(array, 2)  // Copies entire array again
let array = glearray.copy_push(array, 3)  // And again...

/// GOOD - Build list first, convert once
let items = [1, 2, 3]
let array = glearray.from_list(items)
```

**Note:** `gsv.to_dicts` uses `glearray` internally for O(1) header lookups when mapping CSV rows to dicts.
