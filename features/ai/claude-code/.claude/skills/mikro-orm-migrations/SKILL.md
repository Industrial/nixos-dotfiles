---
name: mikro-orm-migrations
description: >-
  Manages MikroORM v7 schema migrations with the Migrator extension: migration:create,
  migration:up/down, schema diff, transactional batches, and programmatic migrator API.
  Use when changing entity metadata, generating DDL, applying migrations, or debugging
  schema drift between entities and the database.
category: framework
displayName: MikroORM Migrations
---

# MikroORM Migrations

## Purpose

Entity metadata is the **source of truth** for DDL. Migrations are generated diffs, reviewed, then applied.

**Docs**: https://mikro-orm.io/docs/migrations · https://mikro-orm.io/docs/schema-generator

---

## 1. Workflow (entities first)

1. Change `defineEntity` metadata in `src/models`.
2. Generate migration from diff.
3. Review generated SQL/TS.
4. Apply migration.
5. Commit entity + migration file together.

**Never** author DDL in Drizzle stubs during Mikro cutover — entities own schema.

---

## 2. Configuration

```typescript
import { Migrator } from '@mikro-orm/migrations'

MikroORM.init({
  extensions: [Migrator],
  migrations: {
    tableName: 'mikro_orm_migrations',
    path: 'src/infrastructure/database/migrations',
    pathTs: 'src/infrastructure/database/migrations',
    glob: '!(*.d).{js,ts}',
    emit: 'ts',
    transactional: true,
    disableForeignKeys: false, // PG: keep FK checks unless you know why not
    safe: true,
    snapshot: false,
  },
})
```

IdClear uses a **separate** `mikro_orm_migrations` table from Drizzle's `__drizzle_migrations` during dual-ORM Phase 1.

---

## 3. CLI commands

```bash
npx mikro-orm migration:create   # diff entities → new migration file
npx mikro-orm migration:up       # apply pending
npx mikro-orm migration:down     # revert one step
npx mikro-orm migration:list     # executed
npx mikro-orm migration:pending  # not yet run
npx mikro-orm migration:check    # schema up to date?
```

### IdClear scripts (`apps/test-nextjs`)

| Script | Purpose |
|--------|---------|
| `bun run db:mikro:migration:create` | Generate migration from entity diff |
| `bun run db:mikro:migrate` | Apply pending migrations |
| `bun run db:mikro:schema:diff` | Check drift (non-zero when out of sync) |
| `bun run db:mikro:migrate:baseline` | Baseline existing DB before first Mikro migration |

`db:generate` / `db:drop` / `db:studio` are frozen — use Mikro tooling instead.

---

## 4. Programmatic API

```typescript
const orm = await MikroORM.init({ extensions: [Migrator], /* ... */ })

await orm.migrator.create()           // new file from diff
await orm.migrator.up()               // latest
await orm.migrator.up({ to: 'name' }) // up to version
await orm.migrator.down()             // one step back
await orm.migrator.rollup()           // squash executed migrations
```

Run inside an existing transaction when needed:

```typescript
await em.transactional(async (tem) => {
  await migrator.up({ transaction: tem.getTransactionContext() })
})
```

---

## 5. Schema generator (dev only)

`orm.schema.update()` / `createSchema()` sync DB directly from metadata — fine for local bootstrap, **not** production.

Production: `orm.migrator.up()` with reviewed migration files.

---

## 6. Checklist

- [ ] Entity change in `src/models` + `entities` export
- [ ] `db:mikro:migration:create` → review SQL
- [ ] `db:mikro:migrate` locally
- [ ] `db:mikro:schema:diff` exits 0
- [ ] Integration tests that touch schema still pass

---

## Anti-patterns

| Bad | Prefer |
|-----|--------|
| Hand-edit live DB without migration | Generate + apply migration |
| `schema.update()` in prod | `migrator.up()` |
| Drizzle `db:generate` for new DDL | Mikro `migration:create` |
| Edit executed migration files | New forward migration |

---

## Next

- Entity metadata → `mikro-orm-entities`
- IdClear config paths → `mikro-orm-idclear`
