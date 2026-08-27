---
title: Disable RLS in Data Migrations
impact: CRITICAL
impactDescription: Silent migration failures - zero rows inserted with FORCE RLS
tags: rls, migrations, cigogne, force-rls, data-integrity
---

## Disable RLS in Data Migrations

After adding `FORCE ROW LEVEL SECURITY` to tables, INSERT statements in migrations silently fail (0 rows inserted) because `core.current_tenant_id()` returns NULL during migration execution. RLS policies evaluate `NULL = NULL` → false, rejecting all rows.

**Incorrect (migration silently fails with FORCE RLS):**

```sql
-- migration:up
INSERT INTO tenant.product (id, tenant_id, name, sku)
VALUES
  (uuid_generate_v7(), 'f47ac10b-...', 'Widget', 'WDG-001'),
  (uuid_generate_v7(), 'f47ac10b-...', 'Gadget', 'GAD-002');

-- Result: 0 rows inserted (NO ERROR!)
-- RLS policy: WHERE tenant_id = (SELECT core.current_tenant_id())
-- Evaluates to: WHERE tenant_id = NULL → always false
```

**Correct (bypass RLS for migration):**

```sql
-- migration:up
SET LOCAL row_security = off;  -- Bypass FORCE RLS for this transaction

INSERT INTO tenant.product (id, tenant_id, name, sku)
VALUES
  (uuid_generate_v7(), 'f47ac10b-...', 'Widget', 'WDG-001'),
  (uuid_generate_v7(), 'f47ac10b-...', 'Gadget', 'GAD-002');

-- Result: 2 rows inserted successfully

-- migration:down
SET LOCAL row_security = off;  -- Also needed for DELETE during rollback

DELETE FROM tenant.product WHERE sku IN ('WDG-001', 'GAD-002');
```

**Idempotency Pattern for Core Data:**

```sql
-- migration:up
SET LOCAL row_security = off;

-- Use ON CONFLICT for idempotent migrations
INSERT INTO core.tenant (id, name, slug)
VALUES (uuid_generate_v7(), 'Demo Corp', 'demo-corp')
ON CONFLICT (slug) DO NOTHING;  -- Safe for re-runs
```

**Cigogne-Specific Notes:**

- Cigogne runs all migrations in a SINGLE transaction
- Partial failures roll back everything (can't use `ON_ERROR_STOP=off`)
- `SET LOCAL` scopes to transaction, safe for migration context
- Manual migration re-insertion requires sha256 hash computation

**Rule:** ALL data migrations (migration:up AND migration:down) that INSERT/UPDATE/DELETE tenant tables must start with `SET LOCAL row_security = off;`

**Source:** Kafka lessons.md (2026-02-14 Mock Data Migration)

Reference: [PostgreSQL Row Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
