---
name: effect.ts-data-modeling
description: >-
  Teaches Effect.ts domain data modeling: Data.TaggedEnum for unions, Data.TaggedError
  for failures, Data.TaggedClass for class-based variants, Schema at boundaries.
  Use when defining domain types, ADTs, DTOs, parse functions, or refactoring plain
  TypeScript types to Effect-native models. Prefer "not this but that" corrections.
category: framework
displayName: Effect.ts Data Modeling
color: purple
---

# Effect.ts Data Modeling

## Purpose

Teach AI assistants how to model domain data in Effect.ts using the right construct for each job. Default to **Data for domain**, **Schema for boundaries**, **TaggedError for Effect failures**.

**Use this skill when**: creating domain types, ADTs, DTOs, parsers, API response shapes, or refactoring manual `_tag` unions and `ok: boolean` responses.

**Prerequisite**: `effect.ts-fundamentals` (Option, Either, pipe, Effect.gen).

---

## Decision Tree

```
Is it an expected failure in an Effect pipeline?
  → Data.TaggedError

Is it a tagged union (decision / state / intent / result)?
  → Data.TaggedEnum + Data.taggedEnum()

Does the variant need methods or form an instruction algebra?
  → Data.TaggedClass (or Data.Class if no _tag needed)

Is it a simple record that must compare by value?
  → Data.struct (or plain readonly type if equality doesn't matter)

Is it unknown external input (HTTP, JWT, query string, env, DB row)?
  → Schema + decodeUnknown → Effect (never throw, never return null silently)
```

### Construct Reference

| Construct | Use for | Gives you |
|-----------|---------|-----------|
| `Data.TaggedEnum` + `Data.taggedEnum()` | Domain unions: decisions, intents, states | `_tag`, constructors, `$match`, `$is`, value equality |
| `Data.TaggedError` | Expected failures in `Effect` | `catchTag`, stack traces, `cause` |
| `Data.TaggedClass` | Class-based variants, instruction algebras | `_tag` + methods + equality |
| `Data.struct` | Simple immutable records needing equality | Value equality without classes |
| `Schema.*` | HTTP bodies, query params, JWT, DB rows | Parse/encode, branded types, refinements |

**Schema is for boundaries.** Domain logic consumes already-validated types; it does not re-parse.

---

## Not This → But That

### Tagged unions (decisions, states, intents)

**Not this** — manual `_tag` union + hand-rolled factories:

```typescript
export type NavigationDecision =
  | { readonly _tag: 'Allow' }
  | { readonly _tag: 'Redirect'; readonly pathname: string; readonly search: string }

export const NavigationDecision = {
  Allow: (): NavigationDecision => ({ _tag: 'Allow' }),
  Redirect: (url: URL): NavigationDecision => ({
    _tag: 'Redirect',
    pathname: url.pathname,
    search: url.search,
  }),
}
```

**But that** — `Data.TaggedEnum` + `Data.taggedEnum()`:

```typescript
import { Data } from 'effect'

export type NavigationDecision = Data.TaggedEnum<{
  Allow: Record<never, never>
  Redirect: { readonly url: URL }
}>

export const NavigationDecision = Data.taggedEnum<NavigationDecision>()

// NavigationDecision.Allow()
// NavigationDecision.Redirect({ url })
// NavigationDecision.$match(decision, { Allow: () => ..., Redirect: ({ url }) => ... })
// NavigationDecision.$is('Redirect')(value)
```

**Why**: value equality, `$match`/`$is`, shared constructors, consistency with `NavigationService` and `CallbackRedirect` in this monorepo.

**Not this** — storing URL pieces separately when a `URL` is the domain concept.

**But that** — keep domain fields semantic (`url: URL`); derive pathname/search at the presentation edge.

---

### Boolean-flag unions

**Not this**:

```typescript
export type OnboardingContinueResponse =
  | { readonly ok: true; readonly redirectPath: string }
  | { readonly ok: false; readonly ambiguous?: true; readonly errorMessage?: string }
```

**But that**:

```typescript
import { Data } from 'effect'

export type OnboardingContinueResponse = Data.TaggedEnum<{
  Success: { readonly redirectPath: string }
  Ambiguous: Record<never, never>
  Failed: { readonly errorMessage: string }
}>

export const OnboardingContinueResponse =
  Data.taggedEnum<OnboardingContinueResponse>()
```

**Why**: `ok: false` plus optional fields is not exhaustive; `$match` forces all cases.

---

### Parse functions

**Not this** — silent `null`:

```typescript
export function parseSubscribeIntent(
  searchParams: URLSearchParams,
): SubscribeIntent | null {
  // ...
  return null
}
```

**But that** — `Option` for optional domain input, or Schema + Effect for required boundary input:

```typescript
import { Option, Schema } from 'effect'

// Optional intent (user may not be subscribing)
export const parseSubscribeIntent = (
  searchParams: URLSearchParams,
): Option.Option<SubscribeIntent> =>
  Option.fromNullable(/* ... */)

// Required input at boundary — Schema + Effect
const SubscribeIntentSchema = Schema.Struct({
  hash: Schema.NonEmptyString,
  token: Schema.NonEmptyString,
  type: Schema.Literal('IndividualSubject', 'LegalEntitySubject'),
})

export const decodeSubscribeIntent = Schema.decodeUnknown(SubscribeIntentSchema)
// Effect.Effect<SubscribeIntent, ParseError>
```

**Rule**: `null` for "invalid input" hides the failure mode. Use `Option` (absent) or `Effect`/`Either` (invalid).

---

### External / wire data

**Not this**:

```typescript
export function decodeJwtPayload(token: string): Record<string, unknown> {
  // try/catch → {}
}
```

**But that** — Schema at boundary, fail explicitly:

```typescript
import { Data, Effect, Schema } from 'effect'

const JwtPayloadSchema = Schema.Struct({
  sub: Schema.optional(Schema.String),
  exp: Schema.optional(Schema.Number),
  // only fields you actually use
})

export class InvalidJwt extends Data.TaggedError('InvalidJwt')<{
  readonly reason: string
}> {}

export const decodeJwtPayload = (token: string) =>
  Effect.gen(function* () {
    const segment = extractPayloadSegment(token)
    const json = yield* Effect.try({
      try: () => base64UrlDecode(segment),
      catch: (cause) => new InvalidJwt({ reason: String(cause) }),
    })
    return yield* Schema.decodeUnknown(JwtPayloadSchema)(json)
  })
```

**Rule**: never swallow parse errors into `{}`. Unknown input becomes `ParseError` or a domain `Data.TaggedError`.

---

### Errors

**Not this**:

```typescript
throw new Error('User not found')
// or Effect.fail('User not found')
// or Effect.fail({ message: '...' })
```

**But that**:

```typescript
import { Data, Effect } from 'effect'

export class UserNotFound extends Data.TaggedError('UserNotFound')<{
  readonly userId: string
}> {}

yield* Effect.fail(new UserNotFound({ userId }))
// Effect.catchTag('UserNotFound', ...)
```

**Not this** — string or plain `Error` in the `E` channel.

**But that** — one `Data.TaggedError` class per failure mode; union them in `E`.

---

### Class-based variants

**Not this** — untagged objects in a manual union:

```typescript
type Instruction = { kind: 'read' } | { kind: 'write'; value: string }
```

**But that** — `Data.TaggedClass` for algebras (see `libs/effect/src/lib/monad/FreeMonad.ts`):

```typescript
import { Data } from 'effect'

export class Read extends Data.TaggedClass('Read')<Record<never, never>> {}
export class Write extends Data.TaggedClass('Write')<{
  readonly value: string
}> {}
export type Instruction = Read | Write
```

Use `TaggedClass` when variants are classes with behavior.

Use `TaggedEnum` when variants are plain data.

---

### Plain types (when they are fine)

**Not this** — forcing `Data` on everything.

**But that** — plain `readonly` types for:

- Static config tables (e.g. route access policy arrays)
- Simple internal DTOs passed once with no equality or match needs
- Type-only re-exports from another module

Add `Data` or `Schema` when you need equality, exhaustive matching, parsing, or Effect error handling.

---

## File Layout Convention (This Monorepo)

```
feature/common/
  domain/     # pure logic, TaggedEnum, parsers → Option/Effect
  types/      # shared readonly shapes (DTOs, API contracts)
```

- **domain/** — constructors, guards, transforms; no React, no fetch.
- **types/** — serializable shapes; pair with Schema when crossing HTTP.
- **Don't duplicate** types already in shared libs — import canonical `NavigationDecision` from `@idclear/frontend`, don't reimplement.

---

## Schema vs Data — Don't Conflate

| | Data | Schema |
|---|------|--------|
| **Where** | Domain layer | Boundary layer |
| **Job** | Model + equality + match | Validate + encode/decode |
| **Output** | Values with `_tag` | `Effect<A, ParseError>` |

**Not this** — `Schema.Class` for every domain type.

**But that** — `Schema` decode at the route/API edge, then map to domain `Data` types inside.

---

## Checklist Before Shipping a New Type

1. Is it a union? → `Data.TaggedEnum` + `taggedEnum()`
2. Is it an Effect failure? → `Data.TaggedError`
3. Does it come from outside? → `Schema` + `decodeUnknown`
4. Is input optional? → `Option`, not `null`
5. Can you `$match` exhaustively instead of `if (x.ok)`?
6. Does an equivalent type exist in shared libs? → import, don't fork

---

## Related Skills

- `effect.ts-fundamentals` — Option, Either, Data intro
- `effect.ts-architect` — services, layers, error channels in context
- `effect.ts-testing` — Layer-based tests for parse/decode paths
- `effect.ts-react` — server/client boundaries in Next.js apps

---

**Remember**: Data models domain truth; Schema validates the outside world; TaggedError carries expected failures through Effect.
