---
title: COALESCE Doesn't Handle Empty Result Sets
impact: HIGH
impactDescription: NULL values when expecting 0 - breaks numeric calculations
tags: coalesce, null-handling, plpgsql, aggregates, gotcha
---

## COALESCE Doesn't Handle Empty Result Sets

`COALESCE(column, default)` only handles NULL values **within rows**. If a SELECT returns zero rows, the variable remains NULL - COALESCE never executes because there's no row to process.

**Incorrect (variable stays NULL on empty result):**

```sql
-- PL/pgSQL trigger function
CREATE OR REPLACE FUNCTION update_stock_quantity() RETURNS TRIGGER AS $$
DECLARE
    v_stock_qty integer;
BEGIN
    -- Query with COALESCE
    SELECT COALESCE(ws.quantity, 0) INTO v_stock_qty
    FROM warehouse_stock ws
    WHERE ws.product_id = NEW.product_id
      AND ws.warehouse_id = NEW.warehouse_id;

    -- If WHERE matches ZERO rows, v_stock_qty is NULL (not 0)!
    -- COALESCE never runs - no rows means no column values

    NEW.available_quantity := v_stock_qty;  -- NULL propagates
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Correct (explicit NULL check after SELECT):**

```sql
CREATE OR REPLACE FUNCTION update_stock_quantity() RETURNS TRIGGER AS $$
DECLARE
    v_stock_qty integer;
BEGIN
    -- Query may return zero rows
    SELECT ws.quantity INTO v_stock_qty
    FROM warehouse_stock ws
    WHERE ws.product_id = NEW.product_id
      AND ws.warehouse_id = NEW.warehouse_id;

    -- Explicit NULL check AFTER SELECT
    IF v_stock_qty IS NULL THEN
        v_stock_qty := 0;
    END IF;

    NEW.available_quantity := v_stock_qty;  -- Guaranteed non-NULL
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Alternative: Use Aggregate with Default**

```sql
-- Aggregates return NULL for empty sets, but you can COALESCE the aggregate result
SELECT COALESCE(SUM(quantity), 0) INTO v_total_stock
FROM warehouse_stock
WHERE product_id = $1;

-- SUM() returns NULL for empty result set
-- COALESCE applies to the aggregate result, not individual rows
-- Works correctly because aggregate result is a single row (even if NULL)
```

**Why This Happens:**

- `SELECT ... INTO` with zero rows leaves variable unchanged (NULL if uninitialized)
- COALESCE operates on column values in returned rows
- Empty result set = no rows = no column values = COALESCE never evaluates

**Rule:** After `SELECT ... INTO` in PL/pgSQL, always check `IF variable IS NULL` before using it in calculations. COALESCE in the SELECT is insufficient for empty result sets.

**Source:** Kafka lessons.md (2026-02-10 PR #51)

Reference: [PL/pgSQL SELECT INTO](https://www.postgresql.org/docs/current/plpgsql-statements.html#PLPGSQL-STATEMENTS-SQL-ONEROW)
