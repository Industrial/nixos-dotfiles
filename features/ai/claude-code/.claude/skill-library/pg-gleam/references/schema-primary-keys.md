---
title: Use UUIDv7 Primary Keys
impact: HIGH
impactDescription: Time-ordered, no fragmentation, distributed-friendly
tags: primary-key, uuid, uuidv7, schema
---

## Use UUIDv7 Primary Keys

Use UUIDv7 via the `pg_uuidv7` extension for all primary keys. UUIDv7 embeds a timestamp, giving time-ordered inserts (no index fragmentation) with globally unique IDs.

**Incorrect (problematic PK choices):**

```sql
-- serial/identity: sequential, predictable, exposes row counts
create table tenant.customer (
  id bigint generated always as identity primary key
);

-- Random UUIDs (v4): cause index fragmentation on large tables
create table tenant.order (
  id uuid default gen_random_uuid() primary key
);
```

**Correct (UUIDv7):**

```sql
-- Enable the extension (once, in extensions schema)
create extension if not exists pg_uuidv7 schema extensions;

-- Use uuid_generate_v7() for all PKs
create table tenant.customer (
  id uuid default uuid_generate_v7() primary key
    constraint pk_customer
);

create table tenant.order (
  id uuid default uuid_generate_v7() primary key
    constraint pk_order,
  customer_id uuid not null
    constraint fk_order_customer references tenant.customer(id)
);
```

Why UUIDv7:

- **Time-ordered**: Embeds millisecond timestamp, so inserts are sequential (good B-tree locality)
- **No fragmentation**: Unlike UUIDv4 which scatters across the index
- **Globally unique**: Safe for distributed systems, no coordination needed
- **Not guessable**: Unlike sequential bigint IDs
- **16 bytes**: Same size as UUIDv4, reasonable index overhead

Guidelines:

- Always use `uuid_generate_v7()` (not `gen_random_uuid()`)
- Install `pg_uuidv7` in the `extensions` schema
- Name the constraint `pk_<table_name>`

Reference: [pg_uuidv7](https://github.com/fboulnois/pg_uuidv7)
