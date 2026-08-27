---
title: Always Use is_local=true for Session Variables
impact: CRITICAL
impactDescription: Tenant isolation breach via connection pool pollution
tags: rls, session-variables, security, connection-pooling, multi-tenancy
---

## Always Use is_local=true for Session Variables

`set_config(..., false)` persists session variables on the connection. In a pooled environment, the next request reusing that connection inherits the previous request's tenant_id, causing catastrophic tenant isolation breaches.

**Incorrect (variable persists on connection):**

```sql
-- WRONG: is_local = false (or omitted, defaults to false)
SELECT set_config('app.tenant_id', $1, false);

-- This variable PERSISTS on the connection after transaction commit!
-- Next request from connection pool: attacker gets victim's tenant_id
```

**Correct (variable scoped to transaction only):**

```sql
-- CORRECT: is_local = true - cleared on commit/rollback
SELECT set_config('app.tenant_id', $1, true);

-- Variable is automatically cleared when transaction ends
-- Connection pool is safe - no cross-request pollution
```

**RLS Policy Pattern:**

```sql
-- RLS policies reference the session variable
CREATE POLICY tenant_isolation ON tenant.orders
    FOR ALL
    USING (tenant_id = (SELECT current_setting('app.tenant_id')::uuid))
    WITH CHECK (tenant_id = (SELECT current_setting('app.tenant_id')::uuid));

-- Helper function for cleaner policies
CREATE FUNCTION core.current_tenant_id() RETURNS uuid AS $$
    SELECT current_setting('app.tenant_id', true)::uuid
$$ LANGUAGE SQL STABLE;
```

**Gleam/POG Pattern:**

```gleam
// Set tenant context at request start
pub fn set_tenant_context(tx: Connection, tenant_id: String) -> Result(Nil, Error) {
  pog.execute(
    "SELECT set_config('app.tenant_id', $1, true)",  // is_local = true!
    tx,
    [pog.text(tenant_id)],
    pog.unit_decoder
  )
}
```

**Rule:** ALWAYS use `is_local = true` (the third parameter). NEVER use `SET` or `set_config(..., false)` for per-request RLS variables.

**Source:** Kafka lessons.md (2026-02-10 PR #52)

Reference: [PostgreSQL set_config](https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-ADMIN-SET)
