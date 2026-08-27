---
title: Optimize RLS Policies for Performance
impact: HIGH
impactDescription: 5-10x faster RLS queries with proper patterns
tags: rls, performance, security, optimization
---

## Optimize RLS Policies for Performance

Poorly written RLS policies can cause severe performance issues. Wrap function calls in `(select ...)` and use security definer functions for complex checks.

**Incorrect (function called for every row):**

```sql
create policy order_policy on tenant.order
  using (core.current_tenant_id() = tenant_id);  -- Called per row!

-- With 1M rows, core.current_tenant_id() is called 1M times
```

**Correct (wrap functions in SELECT):**

```sql
create policy order_policy on tenant.order
  using ((select core.current_tenant_id()) = tenant_id);  -- Called once, cached

-- 100x+ faster on large tables
```

Use security definer functions for complex checks:

```sql
-- Create helper function (runs as definer, bypasses RLS)
create or replace function core.is_team_member(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1 from tenant.team_member
    where team_id = p_team_id
      and user_id = (select core.current_user_id())
      and deleted_at is null
  );
$$;

-- Use in policy (indexed lookup, not per-row check)
create policy team_order_policy on tenant.order
  using ((select core.is_team_member(team_id)));
```

Always add indexes on columns used in RLS policies:

```sql
create index idx_order_tenant_id on tenant.order (tenant_id)
  where deleted_at is null;
create index idx_team_member_lookup on tenant.team_member (team_id, user_id)
  where deleted_at is null;
```

Reference: [Row Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
