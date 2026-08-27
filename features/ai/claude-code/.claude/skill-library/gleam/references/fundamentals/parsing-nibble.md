# Parser Combinators with nibble

Use `nibble` for building composable parsers — tokenize input with a lexer, then parse
token streams into structured data.

## Installation

```sh
gleam add nibble@1
```

## Architecture

nibble follows a **lex-then-parse** pipeline:

1. **Define a token type** — a custom type representing meaningful units
2. **Build a lexer** — converts a raw string into `List(Token(tok))`
3. **Build a parser** — converts token stream into your data structure
4. **Run** — `lexer.run` then `nibble.run`

## Quick Start

```gleam
import gleam/option.{None, Some}
import nibble
import nibble/lexer

// 1. Token type
pub type Token {
  Num(Int)
  LParen
  RParen
  Comma
}

pub type Point {
  Point(x: Int, y: Int)
}

pub fn parse_point(input: String) -> Result(Point, List(nibble.DeadEnd(Token, Nil))) {
  // 2. Lexer
  let my_lexer =
    lexer.simple([
      lexer.int(Num),
      lexer.token("(", LParen),
      lexer.token(")", RParen),
      lexer.token(",", Comma),
      lexer.whitespace(Nil) |> lexer.ignore,
    ])

  // 3. Parser (using do/return style)
  let int_parser = {
    use tok <- nibble.take_map("expected number")
    case tok {
      Num(n) -> Some(n)
      _ -> None
    }
  }

  let parser = {
    use _ <- nibble.do(nibble.token(LParen))
    use x <- nibble.do(int_parser)
    use _ <- nibble.do(nibble.token(Comma))
    use y <- nibble.do(int_parser)
    use _ <- nibble.do(nibble.token(RParen))
    nibble.return(Point(x, y))
  }

  // 4. Run
  let assert Ok(tokens) = lexer.run(input, my_lexer)
  nibble.run(tokens, parser)
}
```

## Core Types

### Parser

```gleam
pub opaque type Parser(a, tok, ctx)
```

- `a` — the value produced on success
- `tok` — the token type being consumed
- `ctx` — context type for error reporting (use `Nil` when not needed)

### DeadEnd (Parse Errors)

```gleam
pub type DeadEnd(tok, ctx) {
  DeadEnd(
    pos: lexer.Span,
    problem: Error(tok),
    context: List(#(lexer.Span, ctx)),
  )
}

pub type Error(tok) {
  BadParser(String)
  Custom(String)
  EndOfInput
  Expected(String, got: tok)
  Unexpected(tok)
}
```

### Loop

```gleam
pub type Loop(a, state) {
  Continue(state)
  Break(a)
}
```

Used with the `loop` combinator for stateful iteration.

## Running Parsers

```gleam
pub fn run(
  src: List(lexer.Token(tok)),
  parser: Parser(a, tok, ctx),
) -> Result(a, List(DeadEnd(tok, ctx)))
```

Takes a token list from `lexer.run` and a parser. Returns `Ok(value)` or
`Error(dead_ends)`.

## Two Composition Styles

### do/return style (recommended — uses `use` syntax)

```gleam
let parser = {
  use x <- nibble.do(parse_x)
  use y <- nibble.do(parse_y)
  nibble.return(Point(x, y))
}
```

### Pipeline style (curried — uses `succeed`/`then`)

```gleam
let parser =
  nibble.succeed(fn(x) { fn(y) { Point(x, y) } })
  |> nibble.then(parse_x)
  |> nibble.then(parse_y)
```

## Primitive Parsers

### return / succeed — Always Succeed

```gleam
nibble.return(value)   // use with do/return style
nibble.succeed(value)  // use with pipeline style
```

Consumes no tokens. Always produces `value`.

### fail / throw — Always Fail

```gleam
nibble.fail("error message")
nibble.throw("error message")
```

Consumes no tokens. Always fails with a `Custom` error.

### token — Match Exact Token

```gleam
nibble.token(LParen)  // succeeds with Nil if next token is LParen
```

### any — Take Next Token

```gleam
nibble.any()  // returns whatever the next token is
```

### eof — End of Input

```gleam
nibble.eof()  // succeeds only if all tokens are consumed
```

### span — Current Position

```gleam
nibble.span()  // returns current Span without consuming
```

### guard — Conditional Check

```gleam
nibble.guard(age >= 13, "must be 13 or older")
```

Fails if condition is `False`.

## Token-Consuming Parsers

### take_map — Match and Transform (Primary Pattern)

```gleam
pub fn take_map(
  expecting: String,
  f: fn(tok) -> Option(a),
) -> Parser(a, tok, ctx)
```

The main way to build token matchers. Return `Some(value)` to match, `None` to reject:

```gleam
let parse_int = {
  use tok <- nibble.take_map("expected integer")
  case tok {
    IntToken(n) -> Some(n)
    _ -> None
  }
}

let parse_string = {
  use tok <- nibble.take_map("expected string")
  case tok {
    StringToken(s) -> Some(s)
    _ -> None
  }
}
```

### take_if — Match with Predicate

```gleam
nibble.take_if("expected identifier", fn(tok) {
  case tok {
    Ident(_) -> True
    _ -> False
  }
})
```

Returns the token itself (not a transformed value).

### take_while / take_while1

```gleam
// Zero or more tokens matching predicate
nibble.take_while(fn(tok) { tok != Newline })

// One or more (fails if none match)
nibble.take_while1("expected at least one", fn(tok) { tok != Newline })
```

### take_until / take_until1

```gleam
// Consume until predicate is True (stop token NOT consumed)
nibble.take_until(fn(tok) { tok == RParen })

// Same but requires at least one token
nibble.take_until1("expected content", fn(tok) { tok == RParen })
```

### take_map_while / take_map_while1

```gleam
// Transform tokens while function returns Some
nibble.take_map_while(fn(tok) {
  case tok {
    Digit(n) -> Some(n)
    _ -> None
  }
})
```

### take_exactly / take_at_least / take_up_to

```gleam
nibble.take_exactly(int_parser, 3)     // exactly 3 ints
nibble.take_at_least(int_parser, 1)    // 1 or more ints
nibble.take_up_to(int_parser, 5)       // 0 to 5 ints
```

## Combinators

### map — Transform Output

```gleam
parse_int
|> nibble.map(fn(n) { n * 2 })
```

### replace — Discard Output

```gleam
nibble.token(Plus) |> nibble.replace(Add)
```

### one_of — Try Alternatives

```gleam
nibble.one_of([
  parse_int |> nibble.map(IntLiteral),
  parse_string |> nibble.map(StringLiteral),
  parse_bool |> nibble.map(BoolLiteral),
])
```

Tries each parser in order. Returns first success. **Does not backtrack** by default —
once a parser consumes a token and fails, `one_of` stops. Wrap with `backtrackable` to
allow retrying.

### many / many1 — Repetition

```gleam
nibble.many(parse_statement)   // zero or more
nibble.many1(parse_statement)  // one or more (fails if none)
```

### sequence — Separated List

```gleam
// Parse comma-separated values
nibble.sequence(parse_expr, nibble.token(Comma))
// "1, 2, 3" -> [1, 2, 3]
```

### optional — Maybe Parse

```gleam
nibble.optional(parse_type_annotation)
// returns Option(a): Some(value) on success, None on failure
```

### or — Default on Failure

```gleam
nibble.or(parse_int, 0)  // returns 0 if parse_int fails
```

### lazy — Recursive Parsers

```gleam
pub fn parse_expr() -> Parser(Expr, Token, Nil) {
  nibble.one_of([
    parse_literal(),
    // lazy breaks the recursion cycle
    nibble.lazy(parse_binary_expr),
  ])
}
```

Essential for recursive grammars. Without `lazy`, Gleam's eager evaluation would cause
an infinite loop when defining recursive parsers.

### backtrackable — Allow Retrying

```gleam
nibble.one_of([
  nibble.backtrackable(try_parse_let),  // if this fails, undo consumed tokens
  parse_expression,                      // and try this instead
])
```

By default, once a parser consumes a token and fails, `one_of` commits to the error.
`backtrackable` undoes the consumption so alternatives can be tried. Use sparingly —
it hurts performance.

### loop — Stateful Iteration

```gleam
nibble.loop([], fn(items) {
  nibble.one_of([
    parse_item
      |> nibble.map(fn(item) { nibble.Continue([item, ..items]) }),
    nibble.eof()
      |> nibble.replace(nibble.Break(list.reverse(items))),
  ])
})
```

### in / do_in — Error Context

```gleam
// Add context for better error messages
let parse_function = {
  use _ <- nibble.do(nibble.token(FnKeyword))
  use name <- nibble.do_in(InFunctionDef, parse_ident)
  use params <- nibble.do_in(InParams, parse_params)
  use body <- nibble.do_in(InBody, parse_body)
  nibble.return(Function(name, params, body))
}
```

When parsing fails inside a context, `DeadEnd.context` includes the context stack,
making error messages more helpful.

## Lexer Module

### Token Type

```gleam
pub type Token(a) {
  Token(span: Span, lexeme: String, value: a)
}

pub type Span {
  Span(row_start: Int, col_start: Int, row_end: Int, col_end: Int)
}
```

### Creating a Lexer

```gleam
pub fn simple(matchers: List(Matcher(a, Nil))) -> Lexer(a, Nil)
```

Matchers are tried in order at each position. First match wins.

### Running a Lexer

```gleam
pub fn run(
  source: String,
  lexer: Lexer(a, Nil),
) -> Result(List(Token(a)), Error)

pub type Error {
  NoMatchFound(row: Int, col: Int, lexeme: String)
}
```

### Built-in Matchers

```gleam
// Exact string match (symbols, punctuation)
lexer.token("(", LParen)
lexer.token("->", Arrow)

// Keywords (won't match inside longer words)
lexer.keyword("let", "[^a-zA-Z0-9_]", Let)
lexer.keyword("fn", "[^a-zA-Z0-9_]", Fn)

// Numbers
lexer.int(IntToken)                           // integers
lexer.float(FloatToken)                       // floats
lexer.number(IntToken, FloatToken)            // int or float
lexer.int_with_separator("_", IntToken)       // 1_000_000
lexer.float_with_separator("_", FloatToken)   // 3.14_159

// Strings (specify delimiter character)
lexer.string("\"", StringToken)               // "hello"

// Identifiers (start pattern, inner pattern, reserved words, constructor)
lexer.identifier("[a-z_]", "[a-zA-Z0-9_]", reserved, Ident)
lexer.variable(reserved, Ident)               // simplified version

// Whitespace
lexer.whitespace(Nil) |> lexer.ignore         // consume and discard
lexer.spaces(Space)                           // consume and keep

// Comments
lexer.comment("//", CommentToken)             // line comments
```

### Matcher Combinators

```gleam
// Discard a matcher's output (whitespace, comments)
lexer.ignore(matcher)

// Transform the token value
lexer.map(matcher, fn(a) { ... })

// Custom matcher (full control)
lexer.custom(fn(mode, lexeme, lookahead) -> Match(a, mode) {
  // Return Keep(value, mode), Skip, Drop(mode), or NoMatch
})

// Simple custom matchers
lexer.keep(fn(lexeme, lookahead) -> Result(a, Nil) { ... })
lexer.drop(fn(lexeme, lookahead) -> Bool { ... })
```

### Match Type

```gleam
pub type Match(a, mode) {
  Keep(a, mode)   // produce token, transition mode
  Skip            // add character to lexeme, keep going
  Drop(mode)      // discard lexeme, transition mode
  NoMatch         // this matcher doesn't apply
}
```

### Advanced Lexer (Mode-Based)

For context-sensitive lexing (string interpolation, indentation):

```gleam
pub type Mode {
  Normal
  InsideString
}

let my_lexer = lexer.advanced(fn(mode: Mode) {
  case mode {
    Normal -> [
      lexer.token("\"", StartString) |> lexer.into(fn(_) { InsideString }),
      // ... normal matchers
    ]
    InsideString -> [
      lexer.token("\"", EndString) |> lexer.into(fn(_) { Normal }),
      // ... string content matchers
    ]
  }
})

// Run with initial mode
lexer.run_advanced(source, Normal, my_lexer)
```

## Pratt Parsing (Operator Precedence)

For expression parsing with operators at different precedence levels:

```gleam
import nibble/pratt

pub type Expr {
  IntLit(Int)
  Negate(Expr)
  Add(Expr, Expr)
  Mul(Expr, Expr)
}

fn parse_expr() -> nibble.Parser(Expr, Token, Nil) {
  pratt.expression(
    // Atoms / prefix operators
    one_of: [
      // Prefix: unary minus
      pratt.prefix(8, nibble.token(Minus), fn(x) { Negate(x) }),
      // Atom: integer literal (receives config for recursive sub-expressions)
      fn(_config) { parse_int() |> nibble.map(IntLit) },
      // Atom: parenthesized expression
      fn(config) {
        use _ <- nibble.do(nibble.token(LParen))
        use expr <- nibble.do(pratt.sub_expression(config, 0))
        use _ <- nibble.do(nibble.token(RParen))
        nibble.return(expr)
      },
    ],
    // Infix / postfix operators
    and_then: [
      pratt.infix_left(4, nibble.token(Plus), fn(l, r) { Add(l, r) }),
      pratt.infix_left(6, nibble.token(Star), fn(l, r) { Mul(l, r) }),
      // pratt.infix_right(precedence, op, fn(l, r) { ... })
      // pratt.postfix(precedence, op, fn(x) { ... })
    ],
    // Whitespace to skip between tokens
    dropping: nibble.token(Whitespace) |> nibble.optional |> nibble.replace(Nil),
  )
}
```

Higher precedence number = tighter binding. Use `pratt.sub_expression(config, 0)` to
recursively parse sub-expressions (0 = accept any precedence).

## Predicates Module

Character classification helpers for custom matchers:

```gleam
import nibble/predicates

predicates.is_digit("5")        // True
predicates.is_lower_ascii("a")  // True
predicates.is_upper_ascii("A")  // True
predicates.is_whitespace(" ")   // True

// Check all characters in a string
predicates.string("hello", predicates.is_lower_ascii)  // True
```

## Complete Example: JSON Parser

```gleam
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/option.{None, Some}
import nibble
import nibble/lexer

pub type Json {
  JNull
  JBool(Bool)
  JNum(Float)
  JStr(String)
  JArr(List(Json))
  JObj(Dict(String, Json))
}

type Token {
  TNull
  TTrue
  TFalse
  TNum(Float)
  TStr(String)
  LBrace
  RBrace
  LBracket
  RBracket
  Colon
  Comma
}

pub fn json_lexer() -> lexer.Lexer(Token, Nil) {
  let breaker = "[^a-zA-Z0-9_]"
  lexer.simple([
    lexer.keyword("null", breaker, TNull),
    lexer.keyword("true", breaker, TTrue),
    lexer.keyword("false", breaker, TFalse),
    lexer.number(fn(n) { TNum(int.to_float(n)) }, TNum),
    lexer.string("\"", TStr),
    lexer.token("{", LBrace),
    lexer.token("}", RBrace),
    lexer.token("[", LBracket),
    lexer.token("]", RBracket),
    lexer.token(":", Colon),
    lexer.token(",", Comma),
    lexer.whitespace(Nil) |> lexer.ignore,
  ])
}

pub fn json_parser() -> nibble.Parser(Json, Token, Nil) {
  nibble.one_of([
    nibble.token(TNull) |> nibble.replace(JNull),
    nibble.token(TTrue) |> nibble.replace(JBool(True)),
    nibble.token(TFalse) |> nibble.replace(JBool(False)),
    {
      use tok <- nibble.take_map("expected number")
      case tok {
        TNum(n) -> Some(JNum(n))
        _ -> None
      }
    },
    {
      use tok <- nibble.take_map("expected string")
      case tok {
        TStr(s) -> Some(JStr(s))
        _ -> None
      }
    },
    nibble.lazy(json_array),
    nibble.lazy(json_object),
  ])
}

fn json_array() -> nibble.Parser(Json, Token, Nil) {
  use _ <- nibble.do(nibble.token(LBracket))
  use items <- nibble.do(
    nibble.sequence(nibble.lazy(json_parser), nibble.token(Comma)),
  )
  use _ <- nibble.do(nibble.token(RBracket))
  nibble.return(JArr(items))
}

fn json_object() -> nibble.Parser(Json, Token, Nil) {
  let parse_pair = {
    use key <- nibble.do({
      use tok <- nibble.take_map("expected string key")
      case tok {
        TStr(s) -> Some(s)
        _ -> None
      }
    })
    use _ <- nibble.do(nibble.token(Colon))
    use value <- nibble.do(nibble.lazy(json_parser))
    nibble.return(#(key, value))
  }

  use _ <- nibble.do(nibble.token(LBrace))
  use pairs <- nibble.do(nibble.sequence(parse_pair, nibble.token(Comma)))
  use _ <- nibble.do(nibble.token(RBrace))
  nibble.return(JObj(dict.from_list(pairs)))
}

pub fn parse(input: String) -> Result(Json, String) {
  case lexer.run(input, json_lexer()) {
    Error(lexer.NoMatchFound(row:, col:, lexeme:)) ->
      Error(
        "Lex error at "
        <> int.to_string(row) <> ":" <> int.to_string(col)
        <> " near '" <> lexeme <> "'",
      )
    Ok(tokens) ->
      case nibble.run(tokens, json_parser()) {
        Ok(json) -> Ok(json)
        Error(_dead_ends) -> Error("Parse error")
      }
  }
}
```

## Best Practices

1. **Always lex first** — nibble parsers operate on `List(Token(tok))`, not raw strings.
   Define a token type and a lexer before writing parsers
2. **Use `take_map` for token matching** — it's the primary way to extract values from
   specific token variants
3. **Use `lazy` for recursive grammars** — Gleam evaluates eagerly, so recursive parser
   definitions need `lazy` to break the cycle
4. **Avoid excessive `backtrackable`** — it hurts performance. Design your token types
   so alternatives can be distinguished by their first token
5. **Use `do`/`return` for complex parsers** — the `use` syntax reads more naturally
   than deeply nested pipelines
6. **Use Pratt parsing for expressions** — `nibble/pratt` handles operator precedence
   cleanly instead of manual precedence climbing
7. **Discard whitespace in the lexer** — `lexer.whitespace(Nil) |> lexer.ignore` keeps
   your parser clean
8. **Use `keyword` not `token` for reserved words** — `keyword` requires a word boundary,
   preventing `"let"` from matching inside `"letter"`
9. **Add context with `in`/`do_in`** — pushes labels onto the error context stack for
   more helpful parse error messages
