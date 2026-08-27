---
name: mikro-orm-querying
description: >-
  Queries MikroORM v7 entities with find/findOne/findAndCount, FilterQuery operators,
  populate strategies, partial fields, filters, and QueryBuilder. Use when writing reads,
  pagination, joins, complex where clauses, or debugging N+1 / populate issues.
category: framework
displayName: MikroORM Querying
---

# MikroORM Querying

## Purpose

Read paths: criteria API first, QueryBuilder when SQL shape matters.

**Docs**: https://mikro-orm.io/docs/entity-manager · https://mikro-orm.io/docs/query-conditions · https://mikro-orm.io/docs/query-builder · https://mikro-orm.io/docs/filters

---

## 1. find / findOne / findAndCount

```typescript
const byId = await em.findOne(User, 1)
const byEmail = await em.findOne(User, { email: 'foo@bar.com' })
const all = await em.find(User, {})

const [rows, total] = await em.findAndCount(
  Author,
  { name: { $like: '%test%' } },
  { limit: 10, offset: 50, orderBy: { name: 'asc' } },
)
```

`findOneOrFail` throws when missing — use at boundaries that expect existence.

---

## 2. Operators (FilterQuery)

| Op | Meaning |
|----|---------|
| `$eq` `$ne` | Equal / not |
| `$gt` `$gte` `$lt` `$lte` | Comparisons |
| `$in` `$nin` | Membership |
| `$like` `$ilike` | LIKE / ILIKE (PG) |
| `$re` | Regexp |
| `$fulltext` | Full-text |
| `$and` `$or` `$not` | Boolean |
| `$overlap` `$contains` `$contained` | PG array/JSONB |
| `$hasKey` `$hasKeys` `$hasSomeKeys` | JSONB keys |

```typescript
await em.find(Author, {
  $or: [{ name: 'Jon' }, { email: { $like: '%winter%' } }],
  age: { $gte: 18 },
})
```

Prefer `unionWhere` over large `$or` when indexes matter (emits `UNION ALL` branches).

---

## 3. Populate & loading strategies

v7 default strategy: **`balanced`** — joined for to-one, select-in for to-many.

| Strategy | Best for |
|----------|----------|
| `select-in` | To-many collections |
| `joined` | To-one / filter on relation in one query |
| `balanced` | Default mix |

```typescript
await em.find(Author, { books: [1, 2, 3] }, {
  populate: ['books'],
  populateWhere: PopulateHint.INFER, // only matching books
})
```

Nested: `populate: ['books.tags', 'address.country']`.

---

## 4. Partial loading

```typescript
await em.findOne(Author, id, {
  fields: ['name', 'books.title', 'books.author'], // include FKs for graph wiring
})
```

PK always selected. Omitting FK columns breaks relation linking.

---

## 5. Filters

Entity-level reusable conditions (soft-delete classic):

```typescript
filters: {
  softDelete: { cond: { deletedAt: null }, default: true },
}
```

Disable per query: `{ filters: { softDelete: false } }` or `em.addFilter` / `setFilterParams`.

---

## 6. QueryBuilder

Use when criteria API is awkward (complex joins, raw fragments, updates/deletes in bulk).

```typescript
const authors = await em
  .createQueryBuilder(Author)
  .select('*')
  .where({ name: { $like: '%test%' } })
  .orderBy({ name: 'asc' })
  .limit(10)
  .getResultList()

const book = await em
  .createQueryBuilder(Book)
  .select('*')
  .where({ id: 1 })
  .getSingleResult()
```

- `getResult` / `getResultList` / `getSingleResult` → managed entities
- `execute` → raw rows (bypass Identity Map)

Import EM from `@mikro-orm/postgresql` for typed QB.

---

## 7. Anti-patterns

| Bad | Prefer |
|-----|--------|
| N+1 loops with `findOne` per row | `populate` / `select-in` |
| `SELECT *` then discard | `fields` |
| Raw SQL for simple filters | FilterQuery operators |
| Ignoring default soft-delete filter | Explicit `filters: false` when intentional |

---

## Next

- Writes → `mikro-orm-persistence`
- Effect `emFind` helpers → `mikro-orm-idclear`
