---
title: Choose Appropriate Data Types
impact: HIGH
impactDescription: 50% storage reduction, faster comparisons, Gleam type safety
tags: data-types, schema, storage, performance, gleam
---

## Choose Appropriate Data Types

Using the right data types reduces storage, improves query performance, and ensures correct Gleam type mapping.

**Incorrect (wrong data types):**

```sql
create table tenant.product (
  id int,                    -- Will overflow at 2.1 billion
  email varchar(255),        -- Unnecessary length limit
  created_at timestamptz,    -- Squirrel doesn't support timestamptz
  is_active varchar(5),      -- String for boolean
  price numeric(10,2)        -- Maps to Gleam Float (lossy!)
);
```

**Correct (appropriate data types):**

```sql
create table tenant.product (
  id uuid default uuid_generate_v7() primary key,  -- UUIDv7 via pg_uuidv7
  email text,                      -- No artificial limit, same performance as varchar
  created_at timestamp not null default now(),  -- Timezone handled at app layer
  is_active boolean default true,  -- 1 byte vs variable string length
  price bigint not null default 0  -- Money as bigint with scale factor 10,000
);
```

**Gleam type mapping (via Squirrel/POG):**

| Postgres Type | Gleam Type | Notes |
|---------------|------------|-------|
| `uuid` | `String` | UUIDv7 for PKs |
| `text` | `String` | Prefer over `varchar(n)` |
| `boolean` | `Bool` | |
| `integer` | `Int` | |
| `bigint` | `Int` | Use for money (exact) |
| `numeric` | `Float` | **Lossy!** Avoid for money |
| `real` / `double precision` | `Float` | |
| `timestamp` | `pog.Timestamp` | No `timestamptz` support |
| `date` | `pog.Date` | |
| `jsonb` | `String` (raw JSON) | Decode in Gleam |
| `bytea` | `BitArray` | |
| `enum` | Generated variant type | See `schema-enums.md` |

Key guidelines:

```
-- IDs: uuid via uuid_generate_v7() (requires pg_uuidv7 extension)
-- Strings: text, not varchar(n) unless a real constraint is needed
-- Money: bigint with scale factor 10,000 (maps to Gleam Int, exact arithmetic)
-- Timestamps: timestamp (not timestamptz); timezone stored in core.tenant.timezone
-- Enums: CREATE TYPE with prefixed values (see schema-enums.md)
```

**Money with bigint scale factor:**

```sql
-- Store $15.50 as 155000 (15.50 * 10,000)
-- Scale factor 10,000 gives 4 decimal places of precision
-- All arithmetic stays in integer domain (exact, no rounding errors)
create table tenant.order_line (
  unit_price bigint not null,   -- e.g. 155000 = $15.50
  quantity integer not null,
  subtotal bigint generated always as (quantity * unit_price) stored
);
```

Reference: [Data Types](https://www.postgresql.org/docs/current/datatype.html)
