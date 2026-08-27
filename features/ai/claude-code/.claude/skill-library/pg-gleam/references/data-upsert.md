---
title: Use UPSERT for Insert-or-Update Operations
impact: MEDIUM
impactDescription: Atomic operation, eliminates race conditions
tags: upsert, on-conflict, insert, update
---

## Use UPSERT for Insert-or-Update Operations

Using separate SELECT-then-INSERT/UPDATE creates race conditions. Use INSERT ... ON CONFLICT for atomic upserts.

**Incorrect (check-then-insert race condition):**

```sql
-- Race condition: two requests check simultaneously
select * from tenant.setting where tenant_id = $1 and key = 'theme';
-- Both find nothing

-- Both try to insert
insert into tenant.setting (tenant_id, key, value)
values ($1, 'theme', 'dark');
-- One succeeds, one fails with duplicate key error!
```

**Correct (atomic UPSERT):**

```sql
-- Single atomic operation
insert into tenant.setting (tenant_id, key, value)
values ($1, 'theme', 'dark')
on conflict (tenant_id, key)
do update set value = excluded.value, updated_at = now();

-- Returns the inserted/updated row
insert into tenant.setting (tenant_id, key, value)
values ($1, 'theme', 'dark')
on conflict (tenant_id, key)
do update set value = excluded.value
returning *;
```

Insert-or-ignore pattern:

```sql
-- Insert only if not exists (no update)
insert into tenant.page_view (page_id, user_id)
values ($1, $2)
on conflict (page_id, user_id) do nothing;
```

Reference: [INSERT ON CONFLICT](https://www.postgresql.org/docs/current/sql-insert.html#SQL-ON-CONFLICT)
