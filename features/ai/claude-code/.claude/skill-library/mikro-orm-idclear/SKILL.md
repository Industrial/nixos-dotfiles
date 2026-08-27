---
name: mikro-orm-idclear
description: >-
  Applies MikroORM v7 inside the IdClear monorepo: @idclear/db Effect tags and layers,
  request-scoped EntityManager forking, emFind/emFlush helpers, entityProps recipes,
  soft-delete and audit subscribers, and test mocks. Use when wiring Mikro in test-nextjs,
  writing Effect Lives/Crud services, or following repo ORM conventions.
category: framework
displayName: MikroORM IdClear
---

# MikroORM — IdClear Monorepo

## Purpose

Repo-specific conventions on top of MikroORM v7 + Effect. Read `mikro-orm-fundamentals` first if EM/Identity Map is unfamiliar.

**Canonical docs**: `libs/db/README.md` · ADR `docs/adr/0001-mikroorm-products-pilot.md`

---

## 1. Layout (non-negotiable)

| What | Where |
|------|--------|
| Entity schemas | `apps/test-nextjs/src/models/*.ts` only |
| Entity registry | `apps/test-nextjs/src/models/index.ts` → `entities` |
| ORM config | `apps/test-nextjs/src/infrastructure/database/mikro-orm.config.ts` |
| Migrations | `apps/test-nextjs/src/infrastructure/database/migrations/` |
| Platform / helpers | `libs/db` (`@idclear/db`) |

**Do not** put EntitySchemas in `libs/db` or under `features/`.

---

## 2. Effect tags & layers

| Tag / Layer | Scope |
|-------------|--------|
| `MikroOrm` | Process singleton (connection pool) |
| `EntityManager` | **Request-scoped** fork per server action / job |
| `MikroPlatformLive` | `createMikroPlatformLive(buildMikroOrmOptions)` |

App wiring (`apps/test-nextjs/src/infrastructure/database/MikroPlatformLive.ts`):

```typescript
import { createMikroPlatformLive } from '@idclear/db'
import { buildMikroOrmOptions } from '@/infrastructure/database/mikro-orm.config'

const { MikroOrmLive, MikroPlatformLive } = createMikroPlatformLive(buildMikroOrmOptions)
```

---

## 3. Request-scoped EntityManager

Server paths fork per request — never share `orm.em` across concurrent calls.

```typescript
import { withForkedRequestEntityManager, runManagedEffect } from '@idclear/db'

// Integration tests (per-call AppLayer)
await Effect.runPromise(
  withForkedRequestEntityManager(myProgram).pipe(Effect.provide(AppLayer)),
)

// Production ManagedRuntime (server actions, activities)
await runManagedEffect(runtime, myProgram)
```

Implementation: `orm.em.fork({ clear: true })` → provide `EntityManager` → `em.clear()` in `finally`.

---

## 4. ORM helpers (prefer over raw `em.*`)

```typescript
import {
  EntityManager,
  emFind,
  emFindOne,
  emCount,
  emFlush,
  emPersistAndFlush,
  emRemoveAndFlush,
  emExecute,
  makeOrmErrorMapper,
  DatabaseError,
} from '@idclear/db'

const dbError = makeOrmErrorMapper(DatabaseError)

const list = Effect.gen(function* () {
  const em = yield* EntityManager
  return yield* emFind(em, ProductSchema, {}, undefined, dbError)
})
```

| Helper | Maps to |
|--------|---------|
| `runOrm` | Any Promise → Effect |
| `emFind` / `emFindOne` / `emCount` | Query |
| `emFlush` | Flush dirty entities |
| `emPersistAndFlush` / `emRemoveAndFlush` | Write + flush |
| `emExecute` | Raw SQL escape hatch |
| `withOrmTransaction` | `em.transactional` + rebind `EntityManager` to `txEm` |

Default error: `PersistenceError`. App boundary: `makeOrmErrorMapper(DatabaseError)`.

---

## 5. Entity property recipes

Import from `@idclear/db` — not `@mikro-orm/core` directly in models:

```typescript
import {
  createdAt,
  updatedAt,
  deletedAt,
  defineEntity,
  p,
  uuidPrimary,
} from '@idclear/db'

export const ProductSchema = defineEntity({
  name: 'Product',
  tableName: 'products',
  class: Product,
  properties: {
    id: uuidPrimary(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
    deletedAt: deletedAt(),
    displayName: p.string().fieldName('display_name'),
  },
  filters: {
    softDelete: { name: 'softDelete', cond: { deletedAt: null }, default: true },
  },
})
```

---

## 6. Cross-cutting subscribers (global)

Registered in `buildMikroOrmOptions` — no per-feature registration:

- **`AuditSubscriber`** — flush-time audit rows → `audit_logs`
- **`SoftDeleteSubscriber`** — DELETE → UPDATE `deletedAt`

All domain writes must go through EM persist/flush so subscribers fire.

---

## 7. Adding a feature (checklist)

1. EntitySchema in `src/models` + `entities` export.
2. Soft-delete filter if table has `deleted_at`.
3. Replace Crud/Live writes with `yield* EntityManager` + helpers.
4. Wire feature layer with `MikroPlatformLive` (not legacy `DatabaseLive`).
5. Unit tests: `entityManagerMockLayer` / `createEntityManagerMock`.
6. Integration: audit proof test (create/update/delete → `audit_logs`).
7. Migration: `bun run db:mikro:migration:create`.

Reference impl: `features/products` + `src/models/Product.ts`.

For full feature-migration WoW, see sibling skill `mikroorm-feature-conversion` when present.

---

## 8. Testing

```typescript
import {
  createEntityManagerMock,
  entityManagerMockLayer,
  withForkedRequestEntityManager,
} from '@idclear/db'

// Unit: mock EM layer
const TestLayer = entityManagerMockLayer({ Product: [seedRow] })

// Integration: real DB + forked EM
withForkedRequestEntityManager(program)
```

---

## Anti-patterns

| Bad | Prefer |
|-----|--------|
| `Effect.tryPromise(() => em.find(...))` everywhere | `emFind` + `dbError` mapper |
| EntitySchema in `libs/db` | `apps/test-nextjs/src/models` |
| Direct `.insert`/`.update` SQL on domain tables | EM persist/flush |
| Skip migration after entity change | `db:mikro:migration:create` |
| Shared global EM in server handlers | `runManagedEffect` / `withForkedRequestEntityManager` |

---

## Related skills

- Generic MikroORM: `mikro-orm-fundamentals`, `entities`, `querying`, `persistence`, `migrations`
- Effect layers: `effect.ts-architect`, `effect.ts-testing`
