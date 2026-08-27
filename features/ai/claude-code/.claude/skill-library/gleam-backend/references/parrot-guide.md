# Parrot SQL Code Generation Guide

## Overview

Parrot generates type-safe Gleam functions from annotated SQL files. It uses [sqlc](https://sqlc.dev/) under the hood to parse SQL and infer types, then produces a single cumulative `sql.gleam` module per `sql/` directory.

For PostgreSQL type mappings, connection config, and SQL patterns (pagination, upsert, etc.), see the **pg-gleam** skill.

## Key Difference from Squirrel

| Feature | Parrot | Squirrel |
|---------|--------|----------|
| Queries per file | **Multiple** (annotated) | One |
| Annotation format | `-- name: QueryName :cmd` | None (filename = query name) |
| Output location | Single `sql.gleam` per `sql/` dir | One `sql.gleam` per module |
| Enum support | Auto-generated types + decoders + `to_string` | Manual |
| Nullable columns | Generates `Option(T)` natively | Non-optional params, optional RETURNING |
| Engine | Downloads sqlc binary (v1.30.0) | Native Gleam |
| Databases | PostgreSQL, MySQL, SQLite | PostgreSQL, MySQL, SQLite |

## Running Parrot

```bash
# Uses DATABASE_URL environment variable
gleam run -m parrot

# Or with explicit database URL
DATABASE_URL=postgres://user:pass@localhost:5432/dbname gleam run -m parrot

# SQLite
gleam run -m parrot --sqlite path/to/db.sqlite
```

Parrot walks the project's `src/` directory, finds all `sql/` subdirectories containing `.sql` files, fetches the database schema (via `pg_dump`), runs sqlc, and generates Gleam code.

## SQL File Format

Each query block starts with an annotation comment. Multiple queries live in a single `.sql` file:

```sql
-- name: GetUserById :one
SELECT id, tenant_id, email, name, created_at
FROM tenant.user
WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL;

-- name: ListUsers :many
SELECT id, tenant_id, email, name, is_active, created_at
FROM tenant.user
WHERE tenant_id = $1 AND deleted_at IS NULL
ORDER BY created_at DESC;

-- name: CreateUser :one
INSERT INTO tenant.user (tenant_id, email, name)
VALUES ($1, $2, $3)
RETURNING id, tenant_id, email, name, created_at;

-- name: UpdateUser :exec
UPDATE tenant.user
SET name = $3, email = $4, updated_at = now()
WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL;

-- name: SoftDeleteUser :exec
UPDATE tenant.user
SET deleted_at = now()
WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL;
```

## Query Command Annotations

| Annotation | Tuple format | Use for |
|------------|-------------|---------|
| `:one` | `#(String, List(Param), Decoder(T))` | SELECT/RETURNING single row |
| `:many` | `#(String, List(Param), Decoder(T))` | SELECT/RETURNING multiple rows |
| `:exec` | `#(String, List(Param))` | UPDATE/DELETE without RETURNING |
| `:execresult` | `#(String, List(Param))` | Same as `:exec` |

**Critical:** `:one` and `:many` generate 3-tuples (with decoder). `:exec` generates 2-tuples (no decoder). Use the matching `db.parrot_one`, `db.parrot_many`, or `db.parrot_exec_no_return` helper at the call site.

### Unsupported Annotations

These will panic at codegen time — do not use:
- `:execrows`, `:execlastid`, `:batchexec`, `:batchmany`, `:batchone`, `:copyfrom`

## Generated Code Structure

For a `:one` query:

```sql
-- name: GetUserById :one
SELECT id, email, name FROM tenant.user WHERE id = $1;
```

Parrot generates:

```gleam
pub type GetUserById {
  GetUserById(
    id: BitArray,
    email: String,
    name: String,
  )
}

pub fn get_user_by_id(id id: BitArray) {
  let sql = "SELECT id, email, name FROM tenant.user WHERE id = $1"
  #(sql, [dev.ParamBitArray(id)], get_user_by_id_decoder())
}

pub fn get_user_by_id_decoder() -> decode.Decoder(GetUserById) {
  use id <- decode.field(0, decode.bit_array)
  use email <- decode.field(1, decode.string)
  use name <- decode.field(2, decode.string)
  decode.success(GetUserById(id:, email:, name:))
}
```

For an `:exec` query (no decoder):

```gleam
pub fn soft_delete_user(id id: BitArray, tenant_id tenant_id: BitArray) {
  let sql = "UPDATE tenant.user SET deleted_at = now() WHERE id = $1 AND tenant_id = $2"
  #(sql, [dev.ParamBitArray(id), dev.ParamBitArray(tenant_id)])
}
```

## Parameter Types (`parrot/dev.Param`)

```gleam
pub type Param {
  ParamInt(Int)
  ParamString(String)
  ParamFloat(Float)
  ParamBool(Bool)
  ParamBitArray(BitArray)
  ParamTimestamp(Timestamp)        // gleam/time/timestamp
  ParamDate(Date)                  // gleam/time/calendar
  ParamList(List(Param))
  ParamDynamic(decode.Dynamic)
  ParamNullable(option.Option(Param))
}
```

## Type Mapping (SQL → Gleam)

| SQL Type | Gleam Type | Param wrapper |
|----------|-----------|---------------|
| `uuid`, `bytea` | `BitArray` | `ParamBitArray` |
| `text`, `varchar`, `char` | `String` | `ParamString` |
| `integer`, `bigint`, `smallint` | `Int` | `ParamInt` |
| `real`, `double`, `numeric` | `Float` | `ParamFloat` |
| `boolean` | `Bool` | `ParamBool` |
| `timestamp`, `timestamptz` | `Timestamp` | `ParamTimestamp` |
| `date` | `Date` | `ParamDate` |
| `array(T)` | `List(T)` | `ParamList` |
| `enum` | Generated variant type | via `to_string` |
| nullable column | `Option(T)` | `ParamNullable` |
| unrecognized / computed | `Dynamic` | `ParamDynamic` |

## Named Parameters with `sqlc.arg()`

By default, positional parameters (`$1`, `$2`) generate opaque labels (`param_1`, `param_2`). Use `sqlc.arg(name)` for readable Gleam function signatures:

```sql
-- name: ListOrdersByDateRange :many
SELECT id, order_date, total
FROM tenant.order
WHERE tenant_id = sqlc.arg(tenant_id)
  AND order_date >= sqlc.arg(start_date)::date
  AND order_date <= sqlc.arg(end_date)::date
  AND deleted_at IS NULL;
```

Generates:

```gleam
pub fn list_orders_by_date_range(
  tenant_id tenant_id: BitArray,
  start_date start_date: Date,
  end_date end_date: Date,
) { ... }
```

### `sqlc.arg` Type Casts

- `sqlc.arg(name)::text` on text columns is a no-op — prefer bare `sqlc.arg(name)`
- Use `::cast` only when Parrot needs disambiguation (e.g., `sqlc.arg(state)::tenant.customer_state` for custom enum types)
- `sqlc.arg(start_date)::date` and `sqlc.arg(end_date)::date` — required when multiple bare `$n` params would generate duplicate Gleam labels

### `sqlc.narg()` — Nullable Parameters

`sqlc.narg(name)` forces a parameter to be nullable regardless of the column's `NOT NULL` constraint. Parrot generates `Option(T)` instead of `T`. There is no `@` shorthand for `sqlc.narg()`.

**Primary use case: partial updates on NOT NULL columns.** Without `sqlc.narg()`, Parrot infers non-nullable types from `NOT NULL` columns, making `COALESCE($n, column)` dead code — the parameter can never be NULL.

```sql
-- name: UpdateAuthor :one
UPDATE author
SET
  -- sqlc.narg → Option(String), caller passes None to keep existing
  name = COALESCE(sqlc.narg('name'), name),
  bio = COALESCE(sqlc.narg('bio'), bio)
WHERE id = sqlc.arg('id')
RETURNING *;
```

Generates:
```gleam
pub fn update_author(
  name name: Option(String),    // None = keep existing
  bio bio: Option(String),      // None = keep existing
  id id: BitArray,
) { ... }
```

**When to use `sqlc.narg()` vs bare `$n`:**

| Column constraint | SQL pattern | Without `sqlc.narg()` | With `sqlc.narg()` |
|---|---|---|---|
| `NOT NULL` | `COALESCE($n, column)` | `T` — COALESCE is dead code | `Option(T)` — partial update works |
| nullable | `COALESCE($n, column)` | `Option(T)` — already works | `Option(T)` — same result, redundant |

**Rule:** Use `sqlc.narg()` for every `COALESCE($n, column)` partial update on a `NOT NULL` column. For nullable columns, bare `$n` already generates `Option(T)`.

**Enum casts with `sqlc.narg()`:** Combine with `::type` cast for enum parameters:
```sql
status = COALESCE(sqlc.narg(new_status)::tenant.fulfillment_item_status, status)
```

## Enum Generation

Parrot auto-generates enum types from PostgreSQL `CREATE TYPE ... AS ENUM`:

```gleam
// Generated from: CREATE TYPE tenant.order_status AS ENUM ('os_pending', 'os_shipped', 'os_delivered')

pub type OrderStatus {
  OsPending
  OsShipped
  OsDelivered
}

pub fn order_status_decoder() -> decode.Decoder(OrderStatus) { ... }

pub fn order_status_to_string(value: OrderStatus) -> String {
  case value {
    OsPending -> "os_pending"
    OsShipped -> "os_shipped"
    OsDelivered -> "os_delivered"
  }
}
```

Use `order_status_to_string()` when passing enum values as parameters.

## Importing Generated Code

Parrot output lives at `kafka/sql.gleam` (or `<project>/sql.gleam`). Import with a clear alias:

```gleam
import kafka/sql as parrot_sql
```

## Built-in Decoders

The `parrot/dev` module provides decoders for non-trivial types:

```gleam
import parrot/dev

// Bool from integer (0/1) or direct boolean
dev.bool_decoder()

// Timestamp from RFC3339 string, tuple, or Unix microseconds
dev.datetime_decoder()

// Calendar date from field tuples
dev.calendar_date_decoder()
```

## Gotchas

### 1. Computed Columns Generate `Option(Dynamic)`

Computed expressions (boolean conditions, `json_agg` subqueries, `CASE WHEN`) produce `Option(Dynamic)` because Parrot cannot infer schema types from expressions.

```sql
-- name: GetOrderWithStatus :one
SELECT id,
  CASE WHEN shipped_at IS NOT NULL THEN true ELSE false END AS is_shipped
FROM tenant.order WHERE id = $1;
```

Generates `is_shipped: Option(Dynamic)`. Decode at the call site:

```gleam
fn dynamic_option_to_bool(opt: Option(Dynamic)) -> Bool {
  case opt {
    Some(d) ->
      decode.run(d, decode.bool)
      |> result.unwrap(False)
    None -> False
  }
}
```

**Detection:** Check generated `sql.gleam` for `Option(Dynamic)` fields after running Parrot.

### 2. LEFT JOIN LATERAL Nullability (sqlc Limitation)

sqlc determines output column nullability **solely from the PostgreSQL schema's `NOT NULL` constraints**. It does **not** propagate nullability through LEFT/RIGHT JOINs. A `NOT NULL` column from a LEFT-JOINed table generates as non-nullable in Gleam, which crashes at runtime when the join produces no matching row.

This is a known sqlc limitation (issues #3240, #4117, #2632). There is no config override, no `sqlc.narg()` for output columns, and no annotation mechanism to force nullable output types.

**Workarounds (in order of preference):**

1. **`CASE WHEN col IS NOT NULL THEN col ELSE NULL END`** — Forces `Option(Dynamic)`. Truthful about nullability. Decode at call site. Use when the field should genuinely be optional.

2. **`COALESCE(col, default)`** — Forces non-nullable type (`String`, `Int`, etc.). Masks NULL with a default value. Use only when an empty/zero default is semantically correct (see Gotcha #8).

3. **Accept `String` and validate in application code** — If the business rule guarantees the row exists (e.g., every supplier must have a CPF/CNPJ), the `NOT NULL` type is correct and validation should happen before the query is called.

```sql
-- Option 1: CASE WHEN → Option(Dynamic), truthful
LEFT JOIN LATERAL (
    SELECT pd.document_value FROM tenant.person_document pd
    WHERE pd.person_id = p.id AND pd.document_type IN ('cpf', 'cnpj')
    LIMIT 1
) dest_doc ON true
-- In SELECT:
CASE WHEN dest_doc.document_value IS NOT NULL
     THEN dest_doc.document_value ELSE NULL END as dest_cpf_cnpj

-- Option 2: COALESCE → String, masks NULL
COALESCE(dest_doc.document_value, '') as dest_cpf_cnpj
```

### 3. Bare `null` in SET Clauses

`SET column = null` causes a silent parse error — the query is skipped entirely.

```sql
-- DON'T: bare null
UPDATE tenant.order SET logistics_error_code = null WHERE id = $1;

-- DO: typed null cast
UPDATE tenant.order SET logistics_error_code = null::tenant.logistics_error_code WHERE id = $1;
```

**Detection:** `grep -n "= null" server/src/*/sql/queries.sql` in Parrot-annotated queries.

### 4. Enum Parameters Need `to_dynamic` FFI

Parrot generates functions expecting `decode.Dynamic` for enum and `char(2)` parameters. Use the standard identity FFI:

```gleam
@external(erlang, "gleam_stdlib", "identity")
fn to_dynamic(value: a) -> decode.Dynamic
```

Then pass enum values as: `to_dynamic(order_status_to_string(status))`

### 5. Array Parameters Not Supported

Parrot cannot generate queries with `WHERE id = ANY($1)` array patterns.

**Workaround:** Use inline `pog.query()` fallback with manual decoder/parameter wiring. Mark with `-- SQLC-SKIP: array param` comment for tracking.

### 6. UNNEST Batch Queries Not Supported

Neither Parrot nor Squirrel supports `UNNEST($1::type[], ...)`. Extract into standalone hand-written `batch.gleam` using `pog.query()` directly.

### 7. Parameter Naming Collisions

Multiple bare `$n` positional parameters that Parrot infers with the same name produce duplicate Gleam labels (compile error).

```sql
-- DON'T: both infer as "date"
WHERE order_date >= $2 AND order_date <= $3

-- DO: explicit names
WHERE order_date >= sqlc.arg(start_date)::date AND order_date <= sqlc.arg(end_date)::date
```

### 8. Nullable Subquery Scalars — COALESCE vs CASE WHEN

Scalar subqueries and LEFT JOIN column references return NULL when no rows match, but sqlc infers the type from the column's `NOT NULL` constraint — producing a non-nullable Gleam type that crashes at runtime.

**Choose based on semantics:**

| Pattern | Generated type | When to use |
|---------|---------------|-------------|
| `COALESCE(subquery, '')` | `String` | Default value is semantically correct (e.g., carrier name → `""` is fine) |
| `CASE WHEN x IS NOT NULL THEN x ELSE NULL END` | `Option(Dynamic)` | NULL is meaningful and should be handled explicitly (e.g., missing CPF/CNPJ → validation error) |
| Bare column from LEFT JOIN | `String` (WRONG) | **Never** — crashes at runtime when join has no match |

```sql
-- COALESCE: masks NULL with default, generates String
SELECT COALESCE((SELECT name FROM tenant.carrier WHERE id = o.carrier_id), '') AS carrier_name
FROM tenant.order o WHERE o.id = $1;

-- CASE WHEN: preserves NULL, generates Option(Dynamic) — decode at call site
SELECT CASE WHEN dest_doc.document_value IS NOT NULL
            THEN dest_doc.document_value ELSE NULL END as dest_cpf_cnpj
FROM ...
LEFT JOIN LATERAL (...) dest_doc ON true;
```

**Important:** Neither pattern should be used on direct UUID columns. Do NOT use `COALESCE(uuid_col::text, '')` — that pattern is forbidden.

### 9. `:one` Does Not Mean "At Most One Row"

The `:one` annotation controls which `db.parrot_*` function to use at the call site. It does not enforce row cardinality — that's your SQL's responsibility (`WHERE id = $1`, `LIMIT 1`).

### 10. UpdateX Returns Its Own Type, Not GetX

Parrot generates separate types for each query. An `UpdateProduct` query returns `UpdateProduct`, not `GetProduct`. Add adapter functions in `view.gleam` when fetch-modify-write operations need type bridging.

### 11. Double JSON Encoding After Migration

When migrating from Squirrel (which used `json.string(body)` for JSONB) to Parrot (which uses `option.Some(body)` for nullable String), watch for `json.to_string(json.string(body))` which double-encodes to `"\"<body>\""`.

**Detection:** `grep -n "json.to_string(json.string(" server/src/`

### 12. Check for Equivalent Query Before Adding New SQL

Adding a query to `queries.sql` may produce redundant code. Before adding `ClearProductImageVariant`, check if existing `AssignProductImageVariant` with `None` param achieves the same effect.

**Pattern:** Collapse `ClearX` + `AssignX` into a single query with `Option(T)` param — pass `None` for clear, `Some(id)` for assign.

### 13. `count(*)::int` Cast is Allowed

`count(*)::int as count` casts aggregate results to integer for correct type inference. This is arithmetic expression casting, NOT the forbidden UUID `::text` pattern.

### 14. Option(T) Import Required

`gleam/option.{type Option}` is not auto-imported. When a function signature uses `Option(T)`, explicitly import `type Option` even if `{None, Some}` are already imported.

### 15. Date Type Conversion

Parrot generates `Option(calendar.Date)` (from `gleam/time/calendar`). If your shared validation module uses a different `Date` type, bridge with:

```gleam
date.parse(s) |> result.map(fn(d) { Some(date.to_calendar_date(d)) })
```

## SQL Authoring Rules

1. **Use `-- name: QueryName :cmd` annotation** on every query block
2. **Use `sqlc.arg(name)` for readable parameter names** — bare `$n` generates `param_n`
3. **Use typed null casts** — `null::tenant.enum_type`, never bare `null`
4. **Prefix enum values** — same rule as Squirrel (`os_pending`, `ps_paid`)
5. **Never edit generated `sql.gleam`** — fix SQL source, re-run Parrot
6. **No `::text` on UUIDs** — Parrot decodes UUIDs as `BitArray` natively
7. **COALESCE only for** aggregate defaults, partial updates, and subquery scalar defaults where empty/zero is semantically correct. Use `CASE WHEN ... ELSE NULL END` when NULL is meaningful
8. **Mark unsupported patterns** with `-- SQLC-SKIP: reason` comments
9. **One `sql/` directory per domain** — Parrot generates one `sql.gleam` per directory
10. **Always commit `.sql` and `sql.gleam` together** — stale generated code causes silent bugs

## Workflow

```
Write/edit SQL → Run `gleam run -m parrot` → Check sql.gleam for Option(Dynamic) → Update handler/view → Commit .sql + sql.gleam together
```
