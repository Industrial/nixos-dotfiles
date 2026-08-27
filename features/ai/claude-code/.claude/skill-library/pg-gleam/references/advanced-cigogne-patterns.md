---
title: Cigogne Single-Transaction Behavior
impact: MEDIUM
impactDescription: Migration recovery complexity - partial failures roll back everything
tags: cigogne, migrations, transactions, idempotency, rollback
---

## Cigogne Single-Transaction Behavior

Cigogne runs all migrations in a single transaction. Partial failures roll back the entire migration batch, not just the failing statement. This requires idempotent patterns for data migrations and prevents PostgreSQL's `ON_ERROR_STOP=off` from working.

**Incorrect (assumes per-statement error handling):**

```sql
-- migration:up
-- Attempting to use ON_ERROR_STOP to skip errors
\set ON_ERROR_STOP off

INSERT INTO core.tenant (id, name, slug)
VALUES (uuid_generate_v7(), 'Demo Corp', 'demo-corp');

INSERT INTO core.tenant (id, name, slug)
VALUES (uuid_generate_v7(), 'Demo Corp', 'demo-corp');  -- Duplicate slug!

-- Expected: First INSERT succeeds, second fails but continues
-- Reality: Entire migration ROLLS BACK (Cigogne's single transaction)
-- Result: 0 rows inserted
```

**Correct (idempotent with ON CONFLICT):**

```sql
-- migration:up
SET LOCAL row_security = off;  -- Bypass FORCE RLS for data migrations

-- Use ON CONFLICT for idempotency
INSERT INTO core.tenant (id, name, slug)
VALUES (uuid_generate_v7(), 'Demo Corp', 'demo-corp')
ON CONFLICT (slug) DO NOTHING;  -- Safe for re-runs

INSERT INTO core.tenant (id, name, slug)
VALUES (uuid_generate_v7(), 'Test Corp', 'test-corp')
ON CONFLICT (slug) DO NOTHING;

-- migration:down
SET LOCAL row_security = off;

DELETE FROM core.tenant WHERE slug IN ('demo-corp', 'test-corp');
```

**Manual Migration Recovery:**

```bash
# After failed migration, check _migrations table
psql -d kafka -c "SELECT * FROM _migrations ORDER BY createdat DESC LIMIT 5;"

# Delete failed migration record to allow re-run
psql -d kafka -c "DELETE FROM _migrations WHERE name = '20260208123456_add_mock_data';"

# Recompute sha256 hash for migration file
sha256sum server/migrations/20260208123456_add_mock_data.sql

# Re-insert migration record if needed
psql -d kafka -c "
  INSERT INTO _migrations (name, createdat, sha256)
  VALUES (
    '20260208123456_add_mock_data',
    '2026-02-08 12:34:56'::timestamp,
    '<hash>'
  );
"

# Re-run migrations
gleam run -m cigogne -- all
```

**Gotchas:**

1. **Cigogne single transaction** - Partial failures roll back everything
2. **`createdat` derived from filename** - Must match `YYYYMMDDHHMMSS` prefix
3. **SHA256 verification** - Hash must match file contents exactly
4. **`_migrations` table** - Cigogne uses this to track applied migrations
5. **`SET LOCAL`** - Scoped to transaction, safe for migration context
6. **No `ON_ERROR_STOP=off`** - PostgreSQL directive doesn't work in transaction

**Idempotency Patterns:**

```sql
-- Schema changes (usually idempotent by default)
CREATE TABLE IF NOT EXISTS tenant.new_table (...);
ALTER TABLE tenant.orders ADD COLUMN IF NOT EXISTS priority integer;
DROP INDEX IF EXISTS tenant.old_index;

-- Data changes (need ON CONFLICT)
INSERT INTO core.tenant (...) VALUES (...) ON CONFLICT (slug) DO NOTHING;
INSERT INTO core.tenant (...) VALUES (...) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- Conditional updates
UPDATE core.tenant SET timezone = 'UTC'
WHERE timezone IS NULL;  -- Only update NULL values
```

**Rule:** All data migrations must be idempotent using `ON CONFLICT` or conditional WHERE clauses. Cannot rely on per-statement error handling - Cigogne's single-transaction behavior rolls back entire batch on any error.

**Source:** Kafka lessons.md (2026-02-14 Mock Data Migration)

Reference: [Cigogne Documentation](https://github.com/levydsa/cigogne)
