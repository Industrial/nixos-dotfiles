---
title: Index Foreign Key Columns
impact: HIGH
impactDescription: 10-100x faster JOINs and CASCADE operations
tags: foreign-key, indexes, joins, schema
---

## Index Foreign Key Columns

Postgres does not automatically index foreign key columns. Missing indexes cause slow JOINs and CASCADE operations.

**Incorrect (unindexed foreign key):**

```sql
create table tenant.order (
  id uuid default uuid_generate_v7() primary key,
  customer_id uuid not null references tenant.customer(id),
  total bigint not null default 0
);

-- No index on customer_id!
-- JOINs and ON DELETE CASCADE both require full table scan
select * from tenant.order where customer_id = $1;  -- Seq Scan
```

**Correct (indexed foreign key):**

```sql
create table tenant.order (
  id uuid default uuid_generate_v7() primary key
    constraint pk_order,
  customer_id uuid not null
    constraint fk_order_customer references tenant.customer(id),
  total bigint not null default 0,
  deleted_at timestamp
);

-- Always index FK columns (with partial index for soft-delete)
create index idx_order_customer_id on tenant.order (customer_id)
  where deleted_at is null;

-- Now JOINs and cascades are fast
select * from tenant.order where customer_id = $1 and deleted_at is null;  -- Index Scan
```

Find missing FK indexes:

```sql
select
  conrelid::regclass as table_name,
  a.attname as fk_column
from pg_constraint c
join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
where c.contype = 'f'
  and not exists (
    select 1 from pg_index i
    where i.indrelid = c.conrelid and a.attnum = any(i.indkey)
  );
```

Reference: [Foreign Keys](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK)
