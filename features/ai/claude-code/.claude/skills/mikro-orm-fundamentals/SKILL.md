---
name: mikro-orm-fundamentals
description: >-
  Teaches MikroORM v7 core architecture: EntityManager, Identity Map, Unit of Work,
  persist vs flush, em.fork(), and RequestContext. Use when learning MikroORM, debugging
  stale entities or identity collisions, setting up per-request EM, or before writing
  entity/query/persistence code.
category: framework
displayName: MikroORM Fundamentals
---

# MikroORM Fundamentals

## Purpose

Stateful ORM mental model before writing queries or entities. MikroORM tracks managed entities and flushes changes as a unit — never share one EM across concurrent requests.

**Use when**: Identity Map confusion, "global context" errors, missing flushes, or onboarding to MikroORM v7.

**Docs**: https://mikro-orm.io/docs/entity-manager · https://mikro-orm.io/docs/identity-map · https://mikro-orm.io/docs/unit-of-work

---

## 1. Architecture (three pieces)

| Piece | Role |
|-------|------|
| **Identity Map** | One JS instance per PK inside an EM; `find` returns the same reference |
| **Unit of Work** | Tracks dirty entities; computes INSERT/UPDATE/DELETE on `flush()` |
| **EntityManager** | API surface for find/persist/remove/flush/transactions |

```typescript
const user = await em.findOne(User, id)
const again = await em.findOne(User, id)
user === again // true — same Identity Map entry

user.bio = 'updated'
await em.flush() // UoW emits UPDATE; no second persist needed
```

---

## 2. Persist vs flush

- `em.persist(entity)` — schedule insert/manage; **no SQL yet**
- `em.flush()` — compute change sets and execute SQL
- `em.persistAndFlush(entity)` — convenience for both
- Managed entities: mutate properties → `flush()` only (no re-persist)

```typescript
const book = await em.findOne(Book, 1)
book.title = 'How to persist things...'
await em.flush() // already managed
```

---

## 3. Fork and RequestContext (mandatory in servers)

**Never** reuse the global `orm.em` across concurrent HTTP/workers. Fork per request (or job):

```typescript
const em = orm.em.fork() // fresh Identity Map + UoW

const user = em.create(User, { email: 'foo@bar.com', fullName: 'Foo Bar' })
await em.flush()
```

Express / similar — wrap handlers with `RequestContext` (forks under the hood):

```typescript
import { RequestContext } from '@mikro-orm/core'

app.use((req, res, next) => {
  RequestContext.create(orm.em, next)
})
```

`em.getContext()` prefers the active `RequestContext` fork; falls back to global EM if none.

**v7 note**: Prefer explicit forks / request scoping. `allowGlobalContext` exists for controlled platforms but does not replace per-request isolation.

---

## 4. Driver imports

Import `MikroORM` / `EntityManager` from the **driver** package when you need QueryBuilder-typed EM:

```typescript
import { MikroORM, EntityManager } from '@mikro-orm/postgresql'
import { defineConfig } from '@mikro-orm/postgresql'
```

Core package alone is enough for entity definitions; SQL QB lives on the driver EM.

---

## 5. Init (v7)

```typescript
const orm = await MikroORM.init(
  defineConfig({
    entities: [Author, Book],
    clientUrl: process.env.DATABASE_URL,
    // driver implied by @mikro-orm/postgresql defineConfig
  }),
)
```

- `MikroORM.init` requires options (no implicit config discovery in v7 sync path).
- `MikroORM.initSync` removed in v7 — use async `init`.
- Default populate strategy in v7: **`balanced`** (joined for to-one, select-in for to-many).

---

## 6. Anti-patterns

| Bad | Why |
|-----|-----|
| Share `orm.em` across requests | Identity Map races, unbounded memory, stale data |
| Expect `persist` alone to write | Must `flush` |
| Mutate detached entities and flush | No change set — re-load or `em.merge` carefully |
| Clear EM mid-request without reason | Breaks Identity Map; prefer short-lived forks |

---

## Next skills

- Define schemas → `mikro-orm-entities`
- Reads → `mikro-orm-querying`
- Writes / txs → `mikro-orm-persistence`
- IdClear Effect wiring → `mikro-orm-idclear`
