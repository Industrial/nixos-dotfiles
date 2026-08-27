# String Character Filtering

Gleam has **no escape sequences** for characters like `\0`, `\n`, `\t` in strings. Use codepoint filtering for binary-level string operations.

## The Problem

```gleam
// WRONG - Gleam doesn't support \0 escape sequence
import gleam/string

pub fn strip_null_bytes(raw: String) -> String {
  string.replace(raw, "\0", "")  // Compile error!
}
```

## The Solution

```gleam
import gleam/string

// Filter out null bytes (codepoint 0)
pub fn strip_null_bytes(raw: String) -> String {
  raw
  |> string.to_utf_codepoints
  |> list.filter(fn(cp) { string.utf_codepoint_to_int(cp) != 0 })
  |> string.from_utf_codepoints
}

// Filter out control characters (0-31)
pub fn strip_control_chars(raw: String) -> String {
  raw
  |> string.to_utf_codepoints
  |> list.filter(fn(cp) {
    let code = string.utf_codepoint_to_int(cp)
    code >= 32  // Keep only printable characters
  })
  |> string.from_utf_codepoints
}

// Replace non-printable with spaces
pub fn sanitize_display_string(raw: String) -> String {
  raw
  |> string.to_utf_codepoints
  |> list.map(fn(cp) {
    let code = string.utf_codepoint_to_int(cp)
    case code >= 32 && code != 127 {
      True -> cp
      False -> {
        // Space character
        let assert Ok(space) = string.utf_codepoint(32)
        space
      }
    }
  })
  |> string.from_utf_codepoints
}
```

## Escape Sequence Table

Gleam does NOT support these common escape sequences:

| Sequence | Meaning | How to Use in Gleam |
|----------|---------|---------------------|
| `\0` | Null byte | `string.utf_codepoint(0)` |
| `\n` | Newline | Use actual newline in multiline string, or `string.utf_codepoint(10)` |
| `\t` | Tab | Use actual tab, or `string.utf_codepoint(9)` |
| `\r` | Carriage return | `string.utf_codepoint(13)` |
| `\\` | Backslash | Works! Gleam supports `\\` for literal backslash |
| `\"` | Quote | Works! Gleam supports `\"` for quotes in strings |

## Pattern: Codepoint Filtering Pipeline

```gleam
import gleam/string
import gleam/list

// Generic codepoint filter
pub fn filter_codepoints(
  input: String,
  predicate: fn(Int) -> Bool,
) -> String {
  input
  |> string.to_utf_codepoints
  |> list.filter(fn(cp) { predicate(string.utf_codepoint_to_int(cp)) })
  |> string.from_utf_codepoints
}

// Example usage
pub fn remove_emojis(text: String) -> String {
  filter_codepoints(text, fn(code) {
    // Basic emoji range (simplified)
    code < 0x1F600 || code > 0x1F64F
  })
}
```

## Why This Matters

- Gleam strings are UTF-8 encoded
- No byte-level string manipulation
- Character filtering requires codepoint conversion
- This is the **only** way to filter specific characters

**Source:** Kafka lessons.md (2026-02-12 PR #121)
