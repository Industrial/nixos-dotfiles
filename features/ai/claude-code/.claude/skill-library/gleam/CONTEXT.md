# gleam — Core Gleam Skill
> Last updated: 2026-07-01

Covers language fundamentals, syntax, type design, and library construction.
For backend logic (Wisp, OTP) use the `gleam-backend` skill.
For frontend logic (Lustre) use the `lustre` skill.

Inherits: `skills/CONTEXT.md`.

## Layout
```
gleam/
├── SKILL.md                         # Main prompt with decision trees
└── references/
    ├── fundamentals/                # Language syntax, patterns, conventions
    │   ├── language-basics.md       # No if, records, imports, constants
    │   ├── language-features.md     # Label shorthand, let assert, pipelines
    │   ├── case-patterns.md         # Pattern matching
    │   ├── code-patterns.md         # use/result.try, helpers
    │   ├── conventions.md           # Official conventions (C1-C10) & anti-patterns (A1-A10)
    │   ├── error-handling.md        # AppError patterns
    │   ├── type-design.md           # Opaque types, parse-don't-validate
    │   ├── decoding.md              # JSON decoding (modern decode API)
    │   ├── decode-map-vs-then.md    # decode.map vs decode.then
    │   ├── stdlib.md                # Useful stdlib functions
    │   ├── stdlib-module-names.md   # Module name gotchas (regexp/regex)
    │   ├── tooling.md               # gleam check/format/fix, LSP actions
    │   ├── common-pitfalls.md       # Frequent mistakes
    │   ├── validation-valid.md      # Input validation (valid library)
    │   ├── parsing-nibble.md        # Parser combinators (nibble)
    │   ├── birdie-snapshot-testing.md
    │   ├── helper-first-refactoring.md
    │   ├── higher-order-sql-helpers.md
    │   └── string-character-filtering.md
    └── library/                     # Library design & FFI
        ├── library-design.md        # Effects as data, no IO in core
        └── ffi.md                   # Erlang + JavaScript FFI
```

## Reference routing
Task- and topic-based routing tables live in `SKILL.md` (single source of truth); every file in the Layout above has a pointer there. Common decoding/pitfall gotchas live in `references/fundamentals/common-pitfalls.md`.
