---
title: Enable Row Level Security for Multi-Tenant Data
impact: CRITICAL
impactDescription: Database-enforced tenant isolation, prevent data leaks
tags: rls, row-level-security, multi-tenant, security
---

## Enable Row Level Security for Multi-Tenant Data

Row Level Security (RLS) enforces data access at the database level, ensuring tenants only see their own data. Use session variables with helper functions for the tenant/user context.

**Incorrect (application-level filtering only):**

```sql
-- Relying only on application to filter
select * from tenant.order where tenant_id = $current_tenant_id;

-- Bug or bypass means all data is exposed!
select * from tenant.order;  -- Returns ALL orders across tenants
```

**Correct (database-enforced RLS with session variables):**

```sql
-- Helper functions (defined once in core schema)
create or replace function core.current_tenant_id()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('app.current_tenant_id', true), '')::uuid;
$$;

create or replace function core.current_user_id()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('app.current_user_id', true), '')::uuid;
$$;

-- Enable RLS on the table
alter table tenant.order enable row level security;

-- Force RLS even for table owners (prevents accidental bypass)
alter table tenant.order force row level security;

-- Create tenant isolation policy
-- Wrap function call in (select ...) so it's evaluated once, not per-row
create policy order_tenant_isolation on tenant.order
  for all
  using (tenant_id = (select core.current_tenant_id()));
```

**Setting session variables (application layer, via POG):**

```sql
-- Set at the start of each request
set_local app.current_tenant_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
set_local app.current_user_id = 'f9e8d7c6-b5a4-3210-fedc-ba9876543210';

-- Now queries are automatically filtered
select * from tenant.order;  -- Only returns orders for this tenant
```

**Always index columns used in RLS policies:**

```sql
create index idx_order_tenant_id on tenant.order (tenant_id)
  where deleted_at is null;
```

Reference: [Row Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
