---
name: mikro-orm-persistence
description: >-
  Persists MikroORM v7 changes via Unit of Work: persist/flush/remove, cascades,
  em.transactional and @Transactional propagation, soft-delete subscribers, and
  flush events. Use when implementing writes, transactions, audit/soft-delete hooks,
  or debugging missing UPDATEs / partial commits.
category: framework
displayName: MikroORM Persistence
---

# MikroORM Persistence

## Purpose

Write path: schedule work on the EM, flush once, wrap multi-step work in transactions.

**Docs**: https://mikro-orm.io/docs/unit-of-work · https://mikro-orm.io/docs/transactions · https://mikro-orm.io/docs/cascading · https://mikro-orm.io/docs/events

---

## 1. Create / update / delete

```typescript
// create
const user = em.create(User, { email: 'a@b.c', fullName: 'Ada' })
await em.persistAndFlush(user)

// update managed
const u = await em.findOneOrFail(User, id)
u.fullName = 'Ada Lovelace'
await em.flush()

// delete (hard, unless soft-delete subscriber)
em.remove(u)
await em.flush()
```

`em.assign(entity, data)` for partial updates from DTOs.

---

## 2. Cascades & orphan removal

Cascade options on relations control whether persist/remove propagates. Prefer explicit persists for clarity unless the domain truly owns children.

- `orphanRemoval: true` on `OneToMany` — removing from collection deletes the child on flush
- Collections: `books.add(book)` / `books.remove(book)` then `flush`

---

## 3. Transactions

```typescript
await em.transactional(async (tem) => {
  tem.persist(em.create(Author, { name: 'Eric' }))
  await tem.flush()
})
```

Nested calls default to **NESTED** (savepoints). Independent side effects (audit that must survive rollback):

```typescript
await em.transactional(async (outer) => {
  // ...
  await em.transactional(
    async (inner) => {
      /* commits separately */
    },
    { propagation: TransactionPropagation.REQUIRES_NEW },
  )
})
```

Decorator form: `@Transactional()` / `@Transactional({ propagation: TransactionPropagation.NESTED })`.

v7: transaction events fire for nested transactions too.

---

## 4. Soft delete (filter + subscriber)

1. Nullable `deletedAt` on entity + **default filter** `{ deletedAt: null }`.
2. `EventSubscriber.onFlush` rewrites `ChangeSetType.DELETE` → `UPDATE` setting `deletedAt`.

```typescript
async onFlush(args: FlushEventArgs): Promise<void> {
  for (const cs of args.uow.getChangeSets()) {
    if (cs.type !== ChangeSetType.DELETE) continue
    if (!cs.meta.properties.deletedAt) continue
    cs.entity.deletedAt = new Date()
    args.uow.computeChangeSet(cs.entity, ChangeSetType.UPDATE)
  }
}
```

Hard delete: disable filter and/or bypass subscriber intentionally.

---

## 5. Events / subscribers

Hook points: `beforeCreate`, `afterUpdate`, `onFlush`, `afterFlush`, etc. Prefer **subscribers** registered in ORM config for cross-cutting audit/soft-delete — keeps entities free of infra.

Serialization for APIs: `wrap(entity).serialize()` / `serialize(entities)` — do not leak managed entities over the wire.

---

## 6. Anti-patterns

| Bad | Prefer |
|-----|--------|
| Multiple flushes in a hot loop | Batch mutates → one flush |
| Catch-and-ignore flush errors mid-tx | Let transactional rollback |
| Manual `DELETE` SQL skipping UoW | `em.remove` so subscribers run |
| Long transactions holding locks | Short critical sections; `REQUIRES_NEW` for side logs |

---

## Next

- Migrations after schema change → `mikro-orm-migrations`
- Effect `emPersistAndFlush` / `withOrmTransaction` → `mikro-orm-idclear`
