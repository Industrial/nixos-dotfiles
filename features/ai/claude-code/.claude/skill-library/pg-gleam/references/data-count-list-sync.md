---
title: Keep Count and List Query Filters in Sync
impact: HIGH
impactDescription: Incorrect pagination - X-Total-Count mismatches actual results
tags: pagination, count-queries, soft-deletes, filters, data-integrity
---

## Keep Count and List Query Filters in Sync

When modifying WHERE clauses in list queries (e.g., adding soft delete filters), corresponding count queries must receive identical filters. Mismatches break pagination because `X-Total-Count` header shows more items than the filtered list actually returns.

**Incorrect (count and list queries diverge):**

```sql
-- list_consigned_stock.sql - INCLUDES soft delete filter
SELECT cs.id, cs.quantity, p.name, p.sku
FROM tenant.consigned_stock cs
JOIN tenant.product p ON p.id = cs.product_id
WHERE cs.warehouse_id = $1
  AND p.deleted_at IS NULL  -- Filter deleted products
ORDER BY cs.created_at DESC
LIMIT $2 OFFSET $3;

-- count_consigned_stock.sql - MISSING soft delete filter
SELECT COUNT(*) as total
FROM tenant.consigned_stock cs
WHERE cs.warehouse_id = $1;
-- Does NOT join product table, counts deleted product stock!

-- Result: If 100 consigned stocks exist but 3 reference deleted products:
-- Count returns: 100
-- List returns: 97 items
-- User sees: "Page 1 of 100" but only 97 items exist
```

**Correct (both queries apply same filters):**

```sql
-- list_consigned_stock.sql
SELECT cs.id, cs.quantity, p.name, p.sku
FROM tenant.consigned_stock cs
JOIN tenant.product p ON p.id = cs.product_id
WHERE cs.warehouse_id = $1
  AND p.deleted_at IS NULL  -- Soft delete filter
ORDER BY cs.created_at DESC
LIMIT $2 OFFSET $3;

-- count_consigned_stock.sql - SAME JOIN + WHERE clause
SELECT COUNT(*) as total
FROM tenant.consigned_stock cs
JOIN tenant.product p ON p.id = cs.product_id  -- Same JOIN
WHERE cs.warehouse_id = $1
  AND p.deleted_at IS NULL;  -- Same soft delete filter

-- Result: Count and list match exactly
-- Count returns: 97
-- List returns: 97 items
-- User sees: "Page 1 of 97" - correct pagination
```

**Prevention Checklist:**

When modifying list query WHERE clauses:
1. Grep for corresponding count query: `count_<entity>.sql`
2. Verify WHERE clause matches (same JOINs, same filters)
3. Test pagination: compare `X-Total-Count` header with actual result length
4. Search for aggregate reports that JOIN the same tables

**Common Drift Patterns:**

- Soft delete filters added to list, missed in count
- RLS bypass in count (admin query) but not in list
- Date range filters in list, missing from count
- Status filters (active/pending) applied inconsistently

**Gleam Handler Pattern:**

```gleam
// Run count and list queries in parallel
let count_result = count_sql.run(db, [warehouse_id])
let list_result = list_sql.run(db, [warehouse_id, limit, offset])

// Both should respect same filters - test by comparing totals
```

**Rule:** When modifying list query WHERE clauses, audit ALL corresponding count queries. Grep for `count_*.sql` in the same directory and verify WHERE clauses mirror the list query filters.

**Source:** Kafka lessons.md (2026-02-12 Issue #55)

Reference: [Pagination Patterns](https://www.postgresql.org/docs/current/queries-limit.html)
