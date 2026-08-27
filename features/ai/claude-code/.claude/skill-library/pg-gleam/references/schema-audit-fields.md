---
title: Add Standard Audit Fields with Triggers
impact: HIGH
impactDescription: Automatic tracking of who created/updated records via session variables
tags: audit, triggers, session-variables, schema
---

## Add Standard Audit Fields with Triggers

Every table should have `created_at`, `updated_at`, `created_by`, and `updated_by` columns. Use triggers to populate them automatically from session variables.

**Standard audit columns:**

```sql
create table tenant.invoice (
  id uuid default uuid_generate_v7() primary key,
  tenant_id uuid not null references core.tenant(id),
  -- ... business columns ...
  created_at timestamp not null default now(),
  updated_at timestamp not null default now(),
  created_by uuid,
  updated_by uuid
);
```

**Trigger functions (defined once in `core` schema):**

```sql
-- Set created_by/updated_by on insert
create or replace function core.set_audit_fields_insert()
returns trigger
language plpgsql
as $$
begin
  new.created_by = core.current_user_id();
  new.updated_by = core.current_user_id();
  return new;
end;
$$;

-- Set updated_by and updated_at on update
create or replace function core.set_audit_fields_update()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  new.updated_by = core.current_user_id();
  -- Prevent overwriting created_by
  new.created_by = old.created_by;
  new.created_at = old.created_at;
  return new;
end;
$$;
```

**Apply triggers per table:**

```sql
create trigger trg_invoice_audit_insert
  before insert on tenant.invoice
  for each row
  execute function core.set_audit_fields_insert();

create trigger trg_invoice_audit_update
  before update on tenant.invoice
  for each row
  execute function core.set_audit_fields_update();
```

**Session variable helper (used by triggers):**

```sql
-- Returns current user ID from session variable, or null if not set
create or replace function core.current_user_id()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('app.current_user_id', true), '')::uuid;
$$;
```

**Setting session variables (done by the application layer):**

```sql
-- POG sets these at the start of each request
set_local app.current_user_id = 'a1b2c3d4-...';
set_local app.current_tenant_id = 'e5f6g7h8-...';
```

Reference: [CREATE TRIGGER](https://www.postgresql.org/docs/current/sql-createtrigger.html)
