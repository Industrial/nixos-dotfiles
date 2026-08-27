# Gleam language basics

Concise reference for core language constructs. Full coverage: [Gleam Tour](https://tour.gleam.run/everything/).

## Modules

- One module per file; module name comes from the file path (e.g. `gleam/io` is `io.gleam` in directory `gleam`).
- `import gleam/io` brings the module in as `io` (last segment of the path).
- `import gleam/string as text` aliases the module.
- Unqualified imports: `import gleam/io.{println}` lets you call `println(...)` or `io.println(...)`.

## Types

- Custom types: `pub type Result(a, e) { Ok(a) | Error(e) }`. Variants are PascalCase.
- Records: named fields, same syntax as custom type constructors with fields.
- Type imports: use `type` to import a type unqualified — `import foo.{type Bar, Bar}` imports the type `Bar` and the constructor `Bar`. Without `type`, only the constructor is available; "no type in scope with that name" usually means you forgot `type`.
- Common types: `Result(a, e)`, `Option(a)`, `List(a)`, `Nil`.

## Functions

- `pub fn` for public, `fn` for private.
- Labeled arguments exist only when the function is **defined** with labels. You cannot add labels at the call site for a function defined with positional parameters.
- Order: all unlabeled arguments first, then labeled (order of labels does not matter).

## Case and blocks

- Each branch of a `case` must be a single expression. For multiple statements in a branch, wrap in `{ ... }`.
- Forgetting braces leads to "I was expecting an expression after this" style errors.

```gleam
case value {
  A -> single_expression_ok()
  B -> {
    let x = something()
    do_more(x)
  }
}
```

## Pipelines

- Use `|>` to pass the left-hand value as the first argument to the right-hand function (or as the sole argument if the right-hand side is a function call that needs it in another position — use function capture for that).
- Idiomatic Gleam: put the "subject" as the first parameter so callers can pipe. Prefer pipes over fluent/curried APIs that return functions.

## Lists

- Immutable single-linked lists. Type: `List(a)`.
- Prepend: `[x, ..existing_list]` or `list.prepend(to: existing_list, this: x)`.
- **Join two lists**: use `list.append(first, second)`. There is **no** `list.concat` in Gleam; use `list.append` or build from cons.
- List pattern: `case list { [first, ..rest] -> ... | _ -> ... }`.

## Naming

- Variables and functions: `snake_case`.
- Types and variants: `PascalCase`.
- Do not use reserved words in directory or module names (e.g. do not use `assert` as a module name; use something like `matchers` instead).
