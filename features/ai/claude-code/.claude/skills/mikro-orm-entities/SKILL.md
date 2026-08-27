---
name: mikro-orm-entities
description: >-
  Defines MikroORM v7 entities with defineEntity and p.* helpers, relationships
  (ManyToOne, OneToMany, ManyToMany), Collection, Ref wrappers, embeddables, and
  EntitySchema patterns. Use when creating or changing entity models, relations,
  embeddables, or property metadata.
category: framework
displayName: MikroORM Entities
---

# MikroORM Entities

## Purpose

Author entity metadata the MikroORM way — prefer **`defineEntity` + `p`** (decorator-free, full inference) over classic `@Entity()` unless a codebase already uses decorators.

**Docs**: https://mikro-orm.io/docs/defining-entities · https://mikro-orm.io/docs/collections · https://mikro-orm.io/docs/embeddables · https://mikro-orm.io/docs/type-safe-relations

---

## 1. defineEntity (preferred)

```typescript
import { defineEntity, InferEntity, p } from '@mikro-orm/core'

export const BookSchema = defineEntity({
  name: 'Book',
  tableName: 'books',
  properties: {
    id: p.bigint().primary(),
    title: p.string(),
    author: () => p.manyToOne(AuthorSchema).ref(),
    tags: () => p.manyToMany(BookTagSchema),
  },
})

export type IBook = InferEntity<typeof BookSchema>
```

With an explicit class (IdClear style):

```typescript
export class Book {
  id!: string
  title!: string
}

export const BookSchema = defineEntity({
  name: 'Book',
  tableName: 'books',
  class: Book,
  properties: {
    id: p.uuid().primary(),
    title: p.string().length(500),
  },
})
```

Lazy relation properties use `() => p.manyToOne(...)` to avoid circular init issues.

---

## 2. Property builders (`p`)

| Helper | Typical use |
|--------|-------------|
| `p.uuid().primary()` | UUID PK |
| `p.string()` / `.length(n)` / `.text()` | Scalars |
| `p.datetime()` / `.onCreate` / `.onUpdate` | Timestamps |
| `p.enum([...]).nativeEnumName('…')` | PG enums |
| `p.json()` | JSON columns |
| `.nullable()` / `.unique()` / `.default(v)` / `.fieldName('snake')` | Column options |
| `p.manyToOne(Schema).ref()` | Owning FK as `Ref` |
| `p.oneToMany(Schema).mappedBy('owner')` | Inverse collection |
| `p.manyToMany(Schema)` | M:N |

---

## 3. Relations

**Owning side** holds the FK (`ManyToOne`). **Inverse** uses `mappedBy` / `OneToMany` + `Collection`.

Decorator equivalent (legacy style):

```typescript
@ManyToOne(() => Author)
author!: Author

@OneToMany(() => Book, (book) => book.author)
books = new Collection<Book>(this)
```

`defineEntity` equivalent:

```typescript
author: () => p.manyToOne(AuthorSchema).ref(),
books: () => p.oneToMany(BookSchema).mappedBy('author'),
```

### Ref wrappers (type-safe)

`.ref()` wraps the relation so unloaded props are not accessible until populate:

```typescript
article.author.id // OK — PK on Ref
article.author.fullName // type error until populated
article.author.$.fullName // after populate: LoadedReference
```

Create with `rel()` / PK / entity instance via `em.create`.

---

## 4. Embeddables

```typescript
@Embeddable()
export class Address {
  @Property() street!: string
  @Property() city!: string
}

@Entity()
export class User {
  @Embedded(() => Address)
  address!: Address
}
```

v7 default embeddable prefix mode is **`relative`**. Array props inside object embeddables default to JSON.

---

## 5. Collections

- Initialize `OneToMany` / `ManyToMany` with `new Collection<T>(this)` (decorator) or schema defaults.
- Mutate via `collection.add` / `remove` / `set`; flush owns SQL.
- Never replace the Collection instance casually — mutate it.

---

## 6. Soft-delete property shape

```typescript
deletedAt: p.datetime().nullable(),
// + filters: { softDelete: { cond: { deletedAt: null }, default: true } }
```

Pair with an `onFlush` subscriber that rewrites DELETE → UPDATE (see `mikro-orm-persistence`).

---

## 7. Checklist for a new entity

- [ ] `name` + `tableName` + PK
- [ ] Snake `fieldName` where DB differs
- [ ] Enums: `nativeEnumName` for existing PG enums
- [ ] Relations: owning FK vs `mappedBy`; prefer `.ref()` on to-one
- [ ] Soft delete filter if `deleted_at` exists
- [ ] Export schema + register in ORM `entities` array
- [ ] Generate migration after metadata change

---

## Next

- Queries → `mikro-orm-querying`
- Flush / soft-delete subscriber → `mikro-orm-persistence`
- IdClear `entityProps` helpers → `mikro-orm-idclear`
