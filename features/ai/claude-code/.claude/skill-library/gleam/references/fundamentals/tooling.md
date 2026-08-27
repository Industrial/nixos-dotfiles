# Tooling Notes

## No Separate Linter

Gleam has NO standalone linter. All lint-like functionality is built into the compiler. The compiler warns about:

- **Unused code**: variables, imports, private functions, modules, recursive function arguments
- **Dead code**: call graph analysis detects unreachable functions including mutual recursion loops
- **Unreachable code**: code after `panic`/`todo`, impossible patterns
- **Redundancy**: redundant `let assert` (total patterns), redundant function captures in pipelines, redundant comparisons (`x == x`)
- **Deprecation**: warns when referencing `@deprecated` items
- **Safety**: `todo`/`echo` reminders, integer overflow on JS target, detached doc comments
- **Shadowing**: warns when local definitions shadow unqualified imports

## Compiler Behavior

- Reports all discoverable errors across independent modules simultaneously rather than stopping at the first error

## Toolchain Commands

- **`gleam check`** — extremely fast type checking, use constantly
- **`gleam format`** — opinionated formatter, zero config, 2-space indent
- **`gleam fix`** — migration tool that rewrites deprecated syntax (NOT a linter autofix)
- **`gleam docs build`** — generates HTML docs from `///` and `////` comments (does not recompile dependencies)
- **`gleam add <package>`** — adds hex dependencies
- **`gleam remove <package>`** — removes hex dependencies
- **`gleam hex owner add`** — add an owner to a hex package
- **`gleam hex retire --package <name> --version <ver> --reason <reason>`** — retire a package version
- **`gleam hex unretire --package <name> --version <ver>`** — unretire a package version

## Language Server Code Actions

The language server provides automatic fixes in your editor:

- Remove unused imports
- Remove redundant tuple wrappers in case
- Auto-import modules
- Add omitted labels (fills with `todo`)
- Convert `let assert` to explicit `case` with `panic`
- Rewrite function calls to pipe syntax
- Convert to label shorthand syntax
- Generate function definitions for undefined functions
- Generate decoders for custom types
- Wrap function references in anonymous functions (or remove trivial wrappers)
- Extract function from pipeline segments and RHS assignments
- Replace `_` type annotations with inferred types
- Record update completions with labelled argument suggestions
- Show diagnostics for files affected by dependency compilation failures
