---
title: Use Generated Columns for Computed Values
impact: MEDIUM
impactDescription: Eliminates application-level computation bugs, always consistent
tags: generated-columns, computed, schema, stored
---

## Use Generated Columns for Computed Values

Use `GENERATED ALWAYS AS ... STORED` for values derived from other columns. The database guarantees consistency.

**Incorrect (application-level computation):**

```sql
create table tenant.order_line (
  id uuid default uuid_generate_v7() primary key,
  order_id uuid not null references tenant.order(id),
  quantity integer not null,
  unit_price bigint not null,
  discount_pct integer not null default 0,
  subtotal bigint,  -- Application must compute and keep in sync
  total bigint      -- Bug-prone: what if discount changes but total isn't updated?
);
```

**Correct (generated columns):**

```sql
create table tenant.order_line (
  id uuid default uuid_generate_v7() primary key,
  order_id uuid not null references tenant.order(id),
  quantity integer not null,
  unit_price bigint not null,       -- Money in bigint (scale 10,000)
  discount_pct integer not null default 0,
  subtotal bigint generated always as (quantity * unit_price) stored,
  total bigint generated always as (
    quantity * unit_price * (100 - discount_pct) / 100
  ) stored
);

-- Values are computed automatically on insert/update
insert into tenant.order_line (order_id, quantity, unit_price, discount_pct)
values ('...', 3, 150000, 10);
-- subtotal = 450000 (3 * 150000)
-- total = 405000 (450000 * 90 / 100)
```

**Indexing generated columns:**

```sql
-- Generated columns can be indexed like regular columns
create index idx_order_line_total on tenant.order_line (total)
  where deleted_at is null;
```

When to use vs application-level computation:

- **Generated column**: Value depends only on columns in the same row
- **Application/trigger**: Value depends on other tables or external data
- **View**: Value is a complex aggregation across multiple rows

Limitations:

- Cannot reference other tables (same-row only)
- Cannot use volatile functions (e.g., `random()`, `now()`)
- Cannot be directly written to (always computed)

Reference: [Generated Columns](https://www.postgresql.org/docs/current/ddl-generated-columns.html)
