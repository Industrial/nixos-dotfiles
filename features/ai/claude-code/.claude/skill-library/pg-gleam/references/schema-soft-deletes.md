---
title: Implement Soft Deletes with Partial Indexes
impact: HIGH
impactDescription: Audit trail preservation, undo capability, FK safety
tags: soft-delete, partial-index, audit, schema
---

## Implement Soft Deletes with Partial Indexes

Use `deleted_at` / `deleted_by` columns instead of hard deletes. Partial indexes keep queries fast by excluding deleted rows.

**Incorrect (hard delete):**

```sql
-- Data is gone forever, no audit trail, FK violations
delete from tenant.order where id = $1;
```

**Correct (soft delete with partial indexes):**

```sql
create table tenant.order (
  id uuid default uuid_generate_v7() primary key,
  tenant_id uuid not null references core.tenant(id),
  customer_id uuid not null references tenant.customer(id),
  total bigint not null default 0,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now(),
  deleted_at timestamp,
  deleted_by uuid
);

-- Partial indexes: only index active rows
create index idx_order_tenant_id on tenant.order (tenant_id) where deleted_at is null;
create index idx_order_customer_id on tenant.order (customer_id) where deleted_at is null;
```

Soft-delete trigger (sets `deleted_by` from session variable):

```sql
create or replace function core.set_soft_delete_fields()
returns trigger
language plpgsql
as $$
begin
  new.deleted_at = now();
  new.deleted_by = core.current_user_id();
  return new;
end;
$$;

-- Apply per table where you want automatic deleted_by tracking
create trigger trg_order_soft_delete
  before update of deleted_at on tenant.order
  for each row
  when (old.deleted_at is null and new.deleted_at is not null)
  execute function core.set_soft_delete_fields();
```

Application-level soft delete:

```sql
-- Soft delete
update tenant.order set deleted_at = now() where id = $1;

-- Query active records (uses partial index)
select * from tenant.order where tenant_id = $1 and deleted_at is null;

-- Query including deleted (for audit)
select * from tenant.order where tenant_id = $1;

-- Restore
update tenant.order set deleted_at = null, deleted_by = null where id = $1;
```

Why soft-delete over hard-delete:

- **Audit trail**: Know what was deleted, when, and by whom
- **Undo**: Restore accidentally deleted records
- **FK safety**: No cascade/restrict issues from delete operations
- **Compliance**: Retain records for regulatory requirements

Reference: [Partial Indexes](https://www.postgresql.org/docs/current/indexes-partial.html)
