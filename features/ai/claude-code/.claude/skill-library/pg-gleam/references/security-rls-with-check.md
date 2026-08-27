---
title: RLS Policies Must Include WITH CHECK Clause
impact: HIGH
impactDescription: Tenant isolation bypass on INSERT/UPDATE operations
tags: rls, security, with-check, multi-tenancy, defense-in-depth
---

## RLS Policies Must Include WITH CHECK Clause

RLS policies with only a `USING` clause filter reads (SELECT) but allow INSERT/UPDATE with arbitrary `tenant_id` values. `WITH CHECK` enforces the same constraint on writes, preventing users from inserting data into other tenants.

**Incorrect (bypasses tenant isolation on writes):**

```sql
-- VULNERABLE: Only USING clause
CREATE POLICY tenant_isolation ON tenant.orders
    FOR ALL
    USING (tenant_id = (SELECT core.current_tenant_id()));

-- What happens:
-- SELECT: Returns only rows matching current tenant (good)
-- INSERT: Can insert with ANY tenant_id value (BAD!)
-- UPDATE: Can change tenant_id to ANY value (BAD!)

-- Attack example:
INSERT INTO tenant.orders (id, tenant_id, customer_id, total)
VALUES (uuid_generate_v7(), 'victim-tenant-id', 123, 1000);
-- Success! Attacker inserted order into victim's tenant
```

**Correct (enforces tenant isolation on reads AND writes):**

```sql
-- SECURE: Both USING and WITH CHECK
CREATE POLICY tenant_isolation ON tenant.orders
    FOR ALL
    USING (tenant_id = (SELECT core.current_tenant_id()))
    WITH CHECK (tenant_id = (SELECT core.current_tenant_id()));

-- What happens:
-- SELECT: Returns only matching tenant rows
-- INSERT: Rejects rows where tenant_id != current_tenant_id()
-- UPDATE: Rejects updates that change tenant_id to wrong value

-- Attack fails:
INSERT INTO tenant.orders (id, tenant_id, customer_id, total)
VALUES (uuid_generate_v7(), 'victim-tenant-id', 123, 1000);
-- ERROR: new row violates row-level security policy for table "orders"
```

**Detection Query:**

```sql
-- Find policies missing WITH CHECK clause
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE with_check IS NULL
  AND schemaname IN ('tenant', 'core');
```

**Migration Pattern:**

```sql
-- migration:up
-- Fix existing policies by dropping and recreating with WITH CHECK
DROP POLICY IF EXISTS tenant_isolation ON tenant.orders;

CREATE POLICY tenant_isolation ON tenant.orders
    FOR ALL
    USING (tenant_id = (SELECT core.current_tenant_id()))
    WITH CHECK (tenant_id = (SELECT core.current_tenant_id()));

-- migration:down
-- Rollback to USING-only (not recommended for production)
DROP POLICY IF EXISTS tenant_isolation ON tenant.orders;

CREATE POLICY tenant_isolation ON tenant.orders
    FOR ALL
    USING (tenant_id = (SELECT core.current_tenant_id()));
```

**Rule:** ALWAYS create policies with `FOR ALL` + `USING` + `WITH CHECK`. Both clauses should use identical expressions for tenant isolation.

**Source:** Kafka lessons.md (2026-02-14 PR #145, Issue #56)

Reference: [PostgreSQL RLS Policies](https://www.postgresql.org/docs/current/sql-createpolicy.html)
