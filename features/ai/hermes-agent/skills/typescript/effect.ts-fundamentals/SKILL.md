---
name: effect.ts-fundamentals
description: >-
  Teaches Effect.ts fundamentals: Effect as a value, pipe/flatMap/currying, FP data types
  (Cause, Either, Option, Data, Chunk, Stream), Schema validation, and composition patterns.
  Use when learning Effect, writing Effect code, or needing FP building blocks before services/layers.
category: framework
displayName: Effect.ts Fundamentals
color: purple
---

# Effect.ts Fundamentals Skill

## Purpose

This skill teaches the foundational concepts of Effect.ts—the building blocks needed before architecting with Layers, Services, and dependency injection. It covers Effect as a value, composition with pipe/flatMap, FP data types, Schema validation, and basic composition patterns.

**Use this skill when**: Learning Effect, writing simple Effect code, needing FP building blocks, or before moving to `effect.ts-architect` for services and Layers.

---

## 1. Effect as a Value

An `Effect` is a **description** of a computation, not the computation itself. It does nothing until you run it with `Effect.runPromise`, `Effect.runSync`, etc.

```typescript
import { Effect } from 'effect'

// This creates a value—no side effect runs yet
const program = Effect.succeed(42)

// Only when you run it does something happen
const result = await Effect.runPromise(program)
// result === 42
```

**Key insight**: Effect separates *description* from *execution*. You can compose, transform, and pass around Effects before running them.

```typescript
// Composing before running
const doubled = Effect.map(program, (n) => n * 2)
const result = await Effect.runPromise(doubled)
// result === 84
```

---

## 2. Pipe and Currying

Effect uses **curried** functions and **pipe** for fluent composition. Choosing between `pipe()` and `Effect.gen()` depends on whether you're composing **Effects** or **non-Effect** values.

### When to use Effect.gen vs pipe

- **Prefer `Effect.gen()`** for functions that work with Effects: multiple sequential steps, branching, or reusing yielded values. It keeps control flow linear and avoids deep `pipe` + `flatMap` chains.
- **Prefer `pipe()`** for functions without effects: pure data transformations, or pipelines over non-Effect types (e.g. `Option`, `Array`, `Chunk`, or a single Effect with only `map`/`tap`).

**Example — prefer Effect.gen for Effect-heavy workflows:**

```typescript
import { Effect } from 'effect'

// ✅ Effect.gen: multiple Effect steps, branching, reusing values
const getUserAndNotify = (userId: string) =>
  Effect.gen(function* () {
    const user = yield* loadUser(userId)
    const validated = yield* validateUser(user)
    if (validated.optOut) return yield* Effect.succeed(null)
    yield* notifyAnalytics(validated)
    return { id: validated.id, email: validated.email }
  })
```

**Example — prefer pipe for non-Effect code or simple Effect pipelines:**

```typescript
import { Effect, pipe, Schema } from 'effect'

// ✅ pipe: pure data transformation (no Effects in the pipeline)
const formatLabel = (user: { name: string; email: string }) =>
  pipe(user, (u) => `${u.name} <${u.email}>`)

// ✅ pipe: single Effect with a short chain (map/tap only)
const parseAndDouble = (input: unknown) =>
  pipe(
    Schema.decodeUnknown(Schema.Number)(input),
    Effect.map((n) => n * 2),
  )
```

### pipe

```typescript
import { Effect, pipe } from 'effect'

// pipe(value, fn1, fn2, fn3) = fn3(fn2(fn1(value)))
const program = pipe(
  Effect.succeed(10),
  Effect.map((n) => n + 1),
  Effect.map((n) => n * 2),
)

const result = await Effect.runPromise(program)
// result === 22
```

### flatMap (chain)

`Effect.flatMap` (alias `Effect.chain`) composes Effects when the next step returns an Effect:

```typescript
const program = pipe(
  Effect.succeed(5),
  Effect.flatMap((n) => Effect.succeed(n * 2)),
  Effect.flatMap((n) => Effect.succeed(n + 1)),
)

const result = await Effect.runPromise(program)
// result === 11
```

**Rule of thumb**:
- `Effect.map`: next step is a pure function `A => B`
- `Effect.flatMap`: next step returns an Effect `A => Effect<B, E, R>`

### Currying

Effect combinators are curried for partial application:

```typescript
const addTen = (n: number) => n + 10
const program = pipe(Effect.succeed(5), Effect.map(addTen))

// Or inline
const program = pipe(
  Effect.succeed(5),
  Effect.map((n) => n + 10),
)
```

### Preferred coding style

**1. Effect workflows** — Prefer `Effect.gen()` when the function is mainly sequencing or branching on Effects:

```typescript
// ✅ Preferred: Effect.gen for multi-step Effect logic
const withFallback = (id: string) =>
  Effect.gen(function* () {
    const user = yield* fetchUser(id)
    if (user) return user
    return yield* loadLegacyUser(id)
  })
```

**2. Pure or short pipelines** — Use `pipe()` for pure transformations or when the pipeline is a short, linear chain (e.g. one Effect + map/tap):

```typescript
// ✅ Preferred: pipe when the value only flows through or is non-Effect
const program = pipe(
  loadUser(id),
  Effect.tap(Effect.log),
  Effect.map((user) => user.email),
)
```

Effect’s curried APIs support both styles; default to **Effect.gen for Effect-heavy functions** and **pipe for non-Effect or simple Effect pipelines**.

---

## 3. Effect Type Parameters

```typescript
Effect<A, E, R>
```

- **A** (Success): The value on success
- **E** (Error): The error type on failure
- **R** (Requirements): Services/dependencies needed (context)

```typescript
// Success with number, no errors, no requirements
const simple: Effect.Effect<number> = Effect.succeed(42)

// Can fail with string
const withError: Effect.Effect<number, string> = Effect.fail("oops")

// Requires HttpClient (covered in architect skill)
const withReq: Effect.Effect<Data, Error, HttpClient.HttpClient> = ...
```

For fundamentals, focus on `A` and `E`; `R` is covered in `effect.ts-architect`.

---

## 4. FP Data Types

### Option

Represents an optional value: `Some(a)` or `None`.

```typescript
import { Option } from 'effect'

const some = Option.some(42)
const none = Option.none

Option.match(some, {
  onNone: () => "missing",
  onSome: (n) => `found ${n}`,
})
// "found 42"

// Convert Option to Effect
const effect = Option.match(some, {
  onNone: () => Effect.fail("not found"),
  onSome: (n) => Effect.succeed(n),
})
```

### Either

Represents success `Right(a)` or failure `Left(e)`.

```typescript
import { Either } from 'effect'

const right = Either.right(42)
const left = Either.left("error")

Either.match(right, {
  onLeft: (e) => `failed: ${e}`,
  onRight: (n) => `ok: ${n}`,
})
// "ok: 42"

// Convert to Effect
const effect = Either.match(right, {
  onLeft: Effect.fail,
  onRight: Effect.succeed,
})
```

### Data

`Data` provides tagged variants, structs, and case classes with built-in equality:

```typescript
import { Data } from 'effect'

class UserNotFound extends Data.TaggedError("UserNotFound")<{
  readonly userId: string
}> {}

class ValidationError extends Data.TaggedError("ValidationError")<{
  readonly field: string
  readonly message: string
}> {}

// Tagged struct
class Person extends Data.TaggedClass("Person")<{
  readonly name: string
  readonly age: number
}> {}

const p = new Person({ name: "Alice", age: 30 })
```

### Cause

`Cause` represents failure reasons: single failures, multiple (parallel) failures, sequential failures, or defects.

```typescript
import { Cause } from 'effect'

const cause = Cause.fail(new Error("boom"))

Cause.match(cause, {
  onEmpty: () => "no cause",
  onFail: (e) => `failed: ${e}`,
  onDie: (defect) => `defect: ${defect}`,
  onInterrupt: (fiberId) => `interrupted`,
  onSequential: (left, right) => `seq`,
  onParallel: (left, right) => `par`,
})
```

### Chunk

Immutable, chunked array optimized for functional pipelines:

```typescript
import { Chunk } from 'effect'

const c = Chunk.make(1, 2, 3)
Chunk.map(c, (n) => n * 2)
Chunk.filter(c, (n) => n > 1)
Chunk.reduce(c, 0, (acc, n) => acc + n)
```

### Stream

Lazy, pull-based streams for async sequences:

```typescript
import { Stream } from 'effect'

const stream = Stream.make(1, 2, 3).pipe(
  Stream.map((n) => n * 2),
  Stream.filter((n) => n > 2),
)

// Run and collect
const chunk = await Effect.runPromise(Stream.runCollect(stream))
```

---

## 5. Schema Validation

Effect Schema provides type-safe encoding, decoding, and validation:

```typescript
import { Schema } from "effect"

const User = Schema.Struct({
  id: Schema.Number,
  name: Schema.String,
  email: Schema.String,
})

type User = Schema.Schema.Type<typeof User>
// { id: number; name: string; email: string }

// Decode (parse) from unknown
const parse = Schema.decodeUnknownSync(User)
const user = parse({ id: 1, name: "Alice", email: "a@b.com" })

// Decode to Effect (doesn't throw)
const decodeEffect = Schema.decodeUnknown(User)
const program = decodeEffect({ id: 1, name: "Alice", email: "a@b.com" })
// Effect.Effect<User, ParseError, never>
```

**With Effect**:

```typescript
const program = pipe(
  Schema.decodeUnknown(User)(input),
  Effect.map((user) => doSomething(user)),
)
```

---

## 6. Basic Composition Patterns

### Sequential with Effect.gen

```typescript
const program = Effect.gen(function* () {
  const a = yield* Effect.succeed(1)
  const b = yield* Effect.succeed(2)
  const c = yield* Effect.succeed(3)
  return a + b + c
})
```

### Parallel with Effect.all

```typescript
const program = Effect.all([
  Effect.succeed(1),
  Effect.succeed(2),
  Effect.succeed(3),
])
// Effect.Effect<[number, number, number]>
```

### Error Handling

```typescript
pipe(
  riskyEffect,
  Effect.catchAll((error) => Effect.succeed(defaultValue)),
  Effect.catchTag("MyError", (e) => Effect.succeed(fallback)),
  Effect.orElse(() => backupEffect),
)
```

### Running Effects

```typescript
// Promise (async)
const value = await Effect.runPromise(program)

// Sync (throws on async)
const value = Effect.runSync(program)

// With custom runtime
import { Runtime } from "effect"
const runtime = Runtime.defaultRuntime
const value = await Runtime.runPromise(runtime)(program)
```

---

## 7. Converting to/from Effect

### Promise → Effect

```typescript
const effect = Effect.tryPromise({
  try: () => fetch(url),
  catch: (e) => new Error(String(e)),
})
```

### Effect → Promise

```typescript
const promise = Effect.runPromise(program)
```

### Sync Throwing → Effect

```typescript
const effect = Effect.try({
  try: () => JSON.parse(str),
  catch: (e) => new Error(String(e)),
})
```

---

## Quick Reference

| Concept | Use When |
|--------|----------|
| `Effect.succeed` | Wrapping a success value |
| `Effect.fail` | Wrapping a failure |
| `Effect.map` | Transform success value (pure) |
| `Effect.flatMap` | Chain Effects |
| `pipe` | Compose **non-Effect** values or short Effect chains (map/tap); prefer for pure data flow |
| `Effect.gen` | **Prefer for Effect-heavy functions**: multiple steps, branching, reusing yielded values |
| `Effect.all` | Parallel composition |
| `Option` | Optional values |
| `Either` | Success/failure before Effect |
| `Data` | Tagged errors and structs |
| `Schema` | Parse and validate data |

---

## Related Skills

- `effect.ts-architect` - Layers, Services, dependency injection
- `effect.ts-testing` - Testing Effect code with Layers
- `typescript-expert` - TypeScript best practices

---

**Remember**: Master these fundamentals before diving into Layers and Services. Effect as a value, pipe/flatMap, and FP data types are the foundation. Prefer **Effect.gen()** for functions that work with Effects; prefer **pipe()** for functions without effects or for short Effect pipelines.
