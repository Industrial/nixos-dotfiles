---
name: gleam
description: Core Gleam language skill. Use when writing pure Gleam functions, parsing or validating input (Parse, Don't Validate), decoding JSON, designing a library, or defining shared domain types — not backend (see gleam-backend) or frontend (see lustre).
---

# Gleam Core Fundamentals

Consolidated skill for pure Gleam development. **Read the relevant reference before writing code.**

## Token Efficiency
Start from `git diff` to scope work, `Grep` for patterns, and read targeted line ranges rather than whole files. Full policy: the repo-root `references/token-efficiency.md`.

## Reference routing — by task

| Task                          | References to read                                                               |
|-------------------------------|----------------------------------------------------------------------------------|
| New to Gleam syntax           | `fundamentals/language-basics.md` + `fundamentals/language-features.md`          |
| Input validation & Types      | `fundamentals/type-design.md` + `fundamentals/validation-valid.md`               |
| JSON Decoding / Encoding      | `fundamentals/decoding.md` + `fundamentals/decode-map-vs-then.md`                |
| Error handling & AppError     | `fundamentals/error-handling.md`                                                 |
| Designing a Library           | `library/library-design.md` + `library/ffi.md`                                   |

## Reference routing — by topic

| Topic                                    | Reference                                       |
|------------------------------------------|-------------------------------------------------|
| Official Conventions (C1-C10)            | `fundamentals/conventions.md`                   |
| Common mistakes / pitfalls               | `fundamentals/common-pitfalls.md`               |
| Pattern Matching                         | `fundamentals/case-patterns.md`                 |
| Code Patterns (use, result.try)          | `fundamentals/code-patterns.md`                 |
| Tooling (check, format, LSP)             | `fundamentals/tooling.md`                       |
| Snapshot testing (birdie)                | `fundamentals/birdie-snapshot-testing.md`       |
| Stdlib functions                         | `fundamentals/stdlib.md`                        |
| Module name gotchas (regexp vs regex)    | `fundamentals/stdlib-module-names.md`           |
| Parser combinators (nibble)              | `fundamentals/parsing-nibble.md`                |
| Helper-first refactoring                 | `fundamentals/helper-first-refactoring.md`      |
| Higher-order SQL helpers                 | `fundamentals/higher-order-sql-helpers.md`      |
| String / character filtering             | `fundamentals/string-character-filtering.md`    |

## Core Principles

- **Parse, Don't Validate** — opaque types for validated data (`fundamentals/type-design.md`).
- **Errors as Values** — one `AppError` type, `Result` everywhere (`fundamentals/error-handling.md`).
