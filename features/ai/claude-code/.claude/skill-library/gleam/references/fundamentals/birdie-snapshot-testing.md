# Snapshot Testing with Birdie

Use `birdie` for snapshot testing — assertions without hand-writing expected values.
Birdie captures output as `.snap` files, fails on differences, and provides an interactive
CLI to review/accept changes.

## Installation

```sh
gleam add --dev birdie
```

## Core API

```gleam
import birdie

/// Snapshot a string value with a unique title.
/// Fails if: no accepted snapshot exists, or accepted snapshot differs.
pub fn snap(content content: String, title title: String) -> Nil

/// CLI entry point — run via `gleam run -m birdie`.
pub fn main() -> Nil
```

**`snap` only accepts `String`.** Convert values explicitly with `string.inspect`,
custom formatters, or `json.to_string` before snapshotting.

## Workflow

1. Write a snapshot test:

```gleam
import birdie
import gleam/string

pub fn greeting_test() {
  "Hello, Lucy!"
  |> birdie.snap(title: "greet user")
}
```

2. Run tests — new/changed snapshots cause test failures:

```sh
gleam test
```

3. Review snapshots interactively — accept or reject each change:

```sh
gleam run -m birdie
```

4. Commit accepted `.snap` files to version control.

## Snapshot Files

Snapshots live in `birdie_snapshots/` at the project root. Each snapshot is a `.snap` file
named after the title (slugified). The file format:

```
---
version: 1.2.3
title: greet user
---
Hello, Lucy!
```

**Commit these files.** They are the source of truth for expected output.

## Rules

- **Unique titles** — every `snap` call must have a globally unique title across the test
  suite. Birdie detects duplicates during review.
- **String only** — no automatic serialization. Explicitly convert: `string.inspect(value)`
  for quick debugging, structured formatters for stable snapshots.
- **Review before accept** — new snapshots always fail until reviewed via the CLI.

## CLI Commands

```sh
gleam run -m birdie          # Interactive review of pending snapshots
gleam run -m birdie help     # Show all available options
```

## When to Use Birdie

- **Complex output** — HTML, JSON, formatted strings where hand-writing expected values
  is tedious and error-prone.
- **Regression detection** — catch unintended changes to serialized output.
- **Golden file testing** — any test where the expected value is best maintained as a file.

## Tips

- Use descriptive titles — they become file names and appear in diffs.
- Prefer structured formatters over `string.inspect` for snapshots that should survive
  refactoring (inspect output changes if type names change).
- Keep snapshot content deterministic — avoid timestamps, random IDs, or system-dependent
  values. Normalize these before snapshotting.
- Add `birdie_snapshots/` to version control, never to `.gitignore`.
