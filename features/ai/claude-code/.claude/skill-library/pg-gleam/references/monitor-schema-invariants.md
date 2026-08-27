---
title: Test Schema Invariants with Catalog Queries
impact: MEDIUM-HIGH
impactDescription: Automatic regression detection for schema-level rules
tags: testing, schema-validation, pg-catalog, regression-prevention, rls
---

## Test Schema Invariants with Catalog Queries

Querying PostgreSQL catalog tables (`pg_class`, `pg_policies`, `information_schema`) in tests automatically catches schema-level regressions when new tables are added. This scales better than testing individual tables.

**Incorrect (manual test for each table):**

```gleam
// Must add new test for every new tenant table
pub fn orders_has_force_rls_test() {
  let policy = get_policy("tenant", "orders")
  policy.force_rls |> should.be_true
}

pub fn products_has_force_rls_test() {
  let policy = get_policy("tenant", "products")
  policy.force_rls |> should.be_true
}

// 50+ tables = 50+ copy-pasted tests
// Forget one table → no test coverage
```

**Correct (catalog query for ALL tables):**

```gleam
// Single test covers all tenant tables automatically
pub fn all_tenant_tables_have_force_rls_test() {
  let sql = "
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'tenant'
      AND tablename NOT IN (
        SELECT tablename FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'tenant'
          AND c.relrowsecurity = true      -- ENABLE RLS
          AND c.relforcerowsecurity = true -- FORCE RLS
      )
  "

  case pog.execute(sql, db, [], decode_table_list) {
    Ok([]) -> Nil  // All tables have FORCE RLS - pass
    Ok(tables) -> {
      let names = string.join(tables, ", ")
      panic as "Tables missing FORCE RLS: " <> names
    }
    Error(e) -> panic as "Query failed: " <> error.to_string(e)
  }
}
```

**Schema Invariant Test Patterns:**

```sql
-- All tenant tables must have FORCE RLS
SELECT tablename FROM pg_tables t
WHERE schemaname = 'tenant'
  AND NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = t.schemaname
      AND c.relname = t.tablename
      AND c.relrowsecurity = true
      AND c.relforcerowsecurity = true
  );

-- All RLS policies must have WITH CHECK clause
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE with_check IS NULL
  AND schemaname IN ('tenant', 'core');

-- All foreign keys should have indexes on referencing column
SELECT c.conname, tc.table_name, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN pg_constraint c ON c.conname = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'tenant'
  AND NOT EXISTS (
    SELECT 1 FROM pg_indexes i
    WHERE i.tablename = tc.table_name
      AND i.indexdef LIKE '%' || kcu.column_name || '%'
  );

-- All tenant tables must have tenant_id column
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'tenant'
  AND table_name NOT IN (
    SELECT table_name FROM information_schema.columns
    WHERE table_schema = 'tenant'
      AND column_name = 'tenant_id'
  );
```

**Gleam Test Pattern:**

```gleam
pub fn enforce_schema_invariant_test() {
  use ctx <- test_helper.with_test_context()

  let violations = check_invariant(ctx.db)

  case violations {
    [] -> Nil  // Pass
    items -> {
      // Custom failure message showing exact violations
      let message = "Schema invariant violated:\n" <> format_violations(items)
      panic as message
    }
  }
}
```

**Benefits:**

1. **Zero maintenance** - test is driven by actual schema
2. **Automatic coverage** - new tables tested immediately
3. **Clear failure messages** - shows exactly which tables violated rule
4. **Regression prevention** - catches mistakes before production

**Rule:** For "all tables must have X" invariants, prefer a `pg_class`/`information_schema` query test over testing individual tables. The test automatically covers new tables without code changes.

**Source:** Kafka lessons.md (2026-02-12 PR #128)

Reference: [PostgreSQL System Catalogs](https://www.postgresql.org/docs/current/catalogs.html)
